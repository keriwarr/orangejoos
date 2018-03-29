require "file_utils"

require "./ast"
require "./compiler_errors"
require "./codegen"
require "./lalr1_table"
require "./lexeme"
require "./name_resolution"
require "./parse_tree"
require "./source_file"
require "./stage"
require "./typing"
require "./weeding"
require "./vtable"
require "./static_analysis"

# The Pipeline executes the compiler pipeline.
class Pipeline
  @sources = [] of SourceFile
  @table = uninitialized LALR1Table
  @end_stage = Stage::CODE_GEN
  @use_stdlib = true
  @verbose = false
  property! output_dir : String

  # initialize creates the pipeline and checks all arguments for validity, raising an ArgumentError
  # if given an invalid parameter.
  def initialize(table_file : String, paths : Array(String))
    # validate arguments
    raise ArgumentError.new("expected a non-zero number of source file paths") if paths.empty?
    raise ArgumentError.new("expected non-empty table file") if table_file.empty?
    raise ArgumentError.new("table file #{table_file} does not exist") if !File.exists?(table_file)

    # load parse table
    @table = LALR1Table.new(File.read_lines(table_file))

    # load source files
    paths.each do |path|
      # check if file
      if File.exists?(path)
        case path
        when /\.java?$/ then @sources.push(SourceFile.new(path))
        else                 raise ArgumentError.new("ERROR: #{path} is not a .java or .jav file")
        end
        # check if directory that may contain java files
      elsif Dir.exists?(path)
        Dir.glob("**/*.java").each { |file| @sources.push(SourceFile.new(file)) }
      else
        raise ArgumentError.new("ERROR: #{path} does not exist")
      end
    end
  end

  # overloaded constructor
  def initialize(table_file : String, paths : Array(String), @end_stage : Stage, @verbose : Bool, @use_stdlib : Bool, @output_dir : String)
    initialize(table_file, paths) # call main constructor
  end

  # do_scan! scans a source file and turns it into tokens, modifying the given source file.
  # may raise an
  def do_scan!(file : SourceFile)
    tokens = Scanner.new(file.contents.to_slice).scan

    # Search for Bad tokens.
    # FIXME: (joey) Collect errors.
    tokens.each do |res|
      if res.typ == Type::Bad
        raise CompilerError.new("tokens=#{tokens}")
      end
    end

    file.tokens = tokens
    return tokens
  rescue ex : CompilerError
    ex.file = file.path
    raise ex
  end

  # do_parse! takes the tokens from a scanned source file and creates a parse tree from it, modifying
  # the given source file to include it. Returns true if the pipeline is successfuly completes up to
  # desired stage. May raise a ParseStageError.
  def do_parse!(table : LALR1Table, file : SourceFile)
    parse_tree = Parser.new(table, file.tokens).parse
    file.parse_tree = parse_tree
    return parse_tree
  rescue ex : CompilerError
    ex.file = file.path
    raise ex
  end

  # do_simplify! simpifies the parse_tree into an abstract syntax tree.
  # May raise a SimplifyStageError.
  def do_simplify!(file : SourceFile)
    ast = Simplification.new.simplify(file.parse_tree).as(AST::File)
    file.ast = ast
    return ast
  rescue ex : CompilerError
    ex.file = file.path
    raise ex
  end

  # do_weed! weeds the abstract suntax tree of errors.
  # May raise a WeedingStageError.
  def do_weed!(file : SourceFile)
    Weeding.new(file.ast, file.class_name).weed
  rescue ex : CompilerError
    ex.file = file.path
    raise ex
  end

  # do_name_resolution! resolves names across all abstract syntax trees
  def self.do_name_resolution!(files : Array(SourceFile), verbose : Bool, use_stdlib : Bool)
    NameResolution.new(files, verbose, use_stdlib).resolve
  end

  # do_type_checking! runs type checks.
  def self.do_type_checking!(file : SourceFile, verbose : Bool)
    TypeCheck.new(file, verbose).check
  rescue ex : CompilerError
    ex.file = file.path
    raise ex
  end

  def self.do_static_analysis!(file : SourceFile)
    StaticAnalysis.new(file).analyze
  rescue ex : CompilerError
    ex.file = file.path
    raise ex
  end

  # do_code_gen generates .s assembly files for the file
  def do_code_gen!(file : SourceFile, vtable : VTable, verbose : Bool, output_dir : String)
    CodeGenerator.new(file, vtable, verbose, output_dir).generate
  rescue ex : CompilerError
    ex.file = file.path
    raise ex
  end

  # exec executes the compiler pipeline up to the specified ending stage.
  # each stage in the pipeline may raise an exception, which should be caught
  # and dealth with by the caller.
  def exec : Bool
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                               SCANNING                                  #
    #                                                                         #
    # Load each source file and scan them into tokens.                        #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    @sources.each { |file| file.read! }
    @sources.each { |file| do_scan!(file) }
    @sources.map &.debug_print(Stage::SCAN) if @verbose
    return true if @end_stage == Stage::SCAN

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                                PARSING                                  #
    #                                                                         #
    # Load LALR(1) prediction table and parse tokens of each source file.     #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    @sources.each { |file| do_parse!(@table, file) }
    # Flatten the parse trees.
    @sources.each { |f| f.parse_tree = ParseSimplification.flatten_tree(f.parse_tree) }
    @sources.map &.debug_print(Stage::PARSE) if @verbose
    return true if @end_stage == Stage::PARSE

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                             SIMPLIFICATION                              #
    #                                                                         #
    # Simplify each parse tree into an abstract syntax tree.                  #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    @sources.each { |file| do_simplify!(file) }
    @sources.map &.debug_print(Stage::SIMPLIFY) if @verbose
    return true if @end_stage == Stage::SIMPLIFY

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                                WEEDING                                  #
    #                                                                         #
    # Weed out any errors that could not be detected by parsing.              #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    @sources.each { |file| do_weed!(file) }
    @sources.map &.debug_print(Stage::WEED) if @verbose
    return true if @end_stage == Stage::WEED

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                             NAME RESOLUTION                             #
    #                                                                         #
    # Resolve any names to their referenced nodes.                            #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    @sources = Pipeline.do_name_resolution!(@sources, @verbose, @use_stdlib)
    @sources.map &.debug_print(Stage::NAME_RESOLUTION) if @verbose
    return true if @end_stage == Stage::NAME_RESOLUTION

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                               TYPE CHECKING                             #
    #                                                                         #
    #                                                                         #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    @sources.each { |file| Pipeline.do_type_checking!(file, @verbose) }
    @sources.map &.debug_print(Stage::TYPE_CHECK) if @verbose
    return true if @end_stage == Stage::TYPE_CHECK

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                              STATIC ANALYSIS                            #
    #                                                                         #
    # Find any remaining errors that we can without actually running the      #
    # code. Note that this stage manipulates the AST by removing ParenExprs,  #
    # and by folding constants expressions.                                       #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    @sources.each { |file| Pipeline.do_static_analysis!(file) }
    @sources.map &.debug_print(Stage::STATIC_ANALYSIS) if @verbose
    return true if @end_stage == Stage::STATIC_ANALYSIS

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                              CODE GENERATION                            #
    #                                                                         #
    #                                                                         #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # Remove existing output content.
    if Dir.exists?(output_dir)
      FileUtils.rm_r(output_dir)
    end
    Dir.mkdir(output_dir)

    # create the magic big vtable for method calling
    vtable = VTable.new(@sources)
    # generate the code
    code_gen = CodeGenerator.new(vtable, @verbose, output_dir)
    @sources.each do |file|
      file.attempt {|f| code_gen.generate(f) }
    end
    code_gen.generate_entry(@sources)
    @sources.map &.debug_print(Stage::CODE_GEN) if @verbose
    return true
  end
end
