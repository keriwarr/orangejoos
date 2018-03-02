require "./lexeme"
require "./ast"
require "./lalr1_table"
require "./parse_tree"
require "./weeding"
require "./compiler_errors"
require "./stage"
require "./source_file"

# The Pipeline executes the compiler pipeline.
class Pipeline
  @sources = [] of SourceFile
  @table = uninitialized LALR1Table
  @end_stage = Stage::ALL
  @verbose = false

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
        else raise ArgumentError.new("ERROR: #{path} is not a .java or .jav file")
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
  def initialize(table_file : String, paths : Array(String), end_stage : String, @verbose : Bool)
    @end_stage = Stage.get(end_stage.downcase)
    initialize(table_file, paths) # call main constructor
  end

  # do_scan! scans a source file and turns it into tokens, modifying the given source file.
  # may raise an
  def do_scan!(file : SourceFile)
    tokens = Scanner.new(file.contents.to_slice).scan

    # Search for Bad tokens.
    # FIXME(joey): Collect errors.
    tokens.each do |res|
      if res.typ == Type::Bad
        raise Exception.new("tokens=#{tokens}")
      end
    end

    file.tokens = tokens
    return tokens
  end

  # do_parse! takes the tokens from a scanned source file and creates a parse tree from it, modifying
  # the given source file to include it. Returns true if the pipeline is successfuly completes up to
  # desired stage. May raise a ParseStageError.
  def do_parse!(table : LALR1Table, file : SourceFile)
    parse_tree = Parser.new(table, file.tokens).parse
    file.parse_tree = parse_tree
    return parse_tree
  end

  # do_simplify! simpifies the parse_tree into an abstract syntax tree.
  # May raise a SimplifyStageError.
  def do_simplify!(file : SourceFile)
    ast = Simplification.new.simplify(file.parse_tree).as(AST::File)
    file.ast = ast
    return ast
  end

  # do_weed! weeds the abstract suntax tree of errors.
  # May raise a WeedingStageError.
  def do_weed!(file : SourceFile)
    Weeding.new(file.ast, file.class_name).weed
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
    #                                  WEEDING                                #
    #                                                                         #
    # Weed out any errors that could not be detected by parsing.              #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    @sources.each { |file| do_weed!(file) }
    @sources.map &.debug_print(Stage::WEED) if @verbose
    return true if @end_stage == Stage::WEED

    # If Stage::ALL
    return true
  rescue ex : Exception
    raise ex
    return false # TODO(slnt) not sure if necessary, probably not though
  end
end
