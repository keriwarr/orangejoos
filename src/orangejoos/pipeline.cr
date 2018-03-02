require "./lexeme"
require "./ast"
require "./lalr1_table"
require "./parse_tree"
require "./weeding"
require "./compiler_errors"
require "./stage"

# A SourceFile represents a file containing source code to be compiled and eventually linked. As the
# pipeline runs the data is modified to
class SourceFile
  property! tokens : Array(Lexeme)
  property! parse_tree : ParseTree
  property! ast : AST::File

  getter! path : String
  getter! contents : String

  def initialize(@path : String)
  end

  def read!
    @contents = File.read(path)
    return contents
  end

  # The type name that this file is allowed to export.
  # - If the file has a hyphen or any special characters, they become
  #   underscores.
  # - If the filename is a keyword, append an underscore. (May not be
  #   relevant, only for packages).
  # - If the filename starts with a digit add an underscore prefix.
  def class_name
    if /\.jav$/ =~ path
      filename = File.basename(path, ".jav")
    else
      filename = File.basename(path, ".java")
    end

    # If the name starts with a number, prefix it with an underscore.
    filename = "_" + filename if filename[0].ascii_number?

    # Replace all invalid name characters with underscores. Only ascii
    # letters, numbers, '$', and '_' are considered valid.
    cleaned_filename = ""
    # new_word = true
    filename.chars.each do |c|
      if c.ascii_letter?
        # if new_word
        #   new_word = false
        #   cleaned_filename += c.upcase
        # else
          cleaned_filename += c
        # end
      elsif c.ascii_number? || c == '$' || c == '_'
        # new_word = true
        cleaned_filename += c
      else
        # new_word = true
        cleaned_filename += "_"
      end
    end

    return cleaned_filename
  end

  def debug_print(stage : Stage)
    case stage
    when Stage::SCAN     then data_type = "lexemes";                     data = @tokens
    when Stage::PARSE    then data_type = "parse tree";                  data = @parse_tree.as?(ParseTree).try &.pprint(0)
    when Stage::SIMPLIFY then data_type = "abstract syntax tree";        data = @ast.as?(AST::File).try &.pprint(0)
    when Stage::WEED     then data_type = "weeded abstract syntax tree"; data = @ast.as?(AST::File).try &.pprint(0)
    end
    STDERR.puts "=== FILE #{data_type}: #{@path} ===\n#{data}"
  end
end

# The Pipeline executes the compiler pipeline.
class Pipeline
  @table_file = ""
  @table = uninitialized LALR1Table
  @paths = [] of String
  @end_stage = Stage::ALL
  @verbose = false

  def initialize(@table_file : String, @paths : Array(String))
    validate # make sure args are correct
  end

  def initialize(@table_file : String, @paths : Array(String), end_stage : String, @verbose : Bool)
    @end_stage = Stage.get(end_stage.downcase)
    validate # make sure args are correct
  end

  def validate
    raise ArgumentError.new("expected a non-zero number of source file paths") if @paths.empty?
    raise ArgumentError.new("expected non-empty table file") if @table_file.empty?
    unless File.exists?(@table_file)
      raise ArgumentError.new("table file #{@table_file} does not exist")
    end
  end

  # do_scan! scans a source file and turns it into tokens, modifying the given source file.
  def do_scan!(file : SourceFile)
    begin
      tokens = Scanner.new(file.contents.to_slice).scan
    rescue ex : ScanningStageError
      STDERR.puts "Failed #{file.path} to scan with exception: #{ex}"
      exit 42
    end

    # Search for Bad tokens.
    # FIXME(joey): Collect errors.
    tokens.each do |res|
      if res.typ == Type::Bad
        STDERR.puts "Failed #{file.path} to parse, got tokens: "
        STDERR.puts tokens
        exit 42
      end
    end

    file.tokens = tokens
    return tokens
  end

  #do_parse! takes the tokens from a scanned source file and creates a parse tree from it, modifying
  # the given source file to include it
  def do_parse!(table : LALR1Table, file : SourceFile)
    begin
      parse_tree = Parser.new(table, file.tokens).parse
    rescue ex : ParseStageError
      STDERR.puts "Failed #{file.path} to parse with exception: #{ex}"
      exit 42
    end
    file.parse_tree = parse_tree
    return parse_tree
  end

  # do_simplify! simpifies the parse_tree into an abstract syntax tree
  def do_simplify!(file : SourceFile)
    begin
     ast = Simplification.new.simplify(file.parse_tree).as(AST::File)
    rescue ex : SimplifyStageError
      STDERR.puts "Failed #{file.path} to simplify with exception: #{ex}"
      exit 42
    end
    file.ast = ast
    return ast
  end

  # do_weed! weeds the abstract suntax tree of errors
  def do_weed!(file : SourceFile)
    begin
     Weeding.new(file.ast, file.class_name).weed
    rescue ex : WeedingStageError
      STDERR.puts "Found #{file.path} weeding error: #{ex}"
      exit 42
    end
  end

  # load parse tree loads the parse tree from the file given to the pipeline
  def load_parse_table
    # Check that the table file exists.
    unless File.exists?(@table_file)
      STDERR.puts "ERROR: file #{@table_file} does not exist"
      exit 1
    end

    table_contents = File.read_lines(@table_file)
    table = LALR1Table.new(table_contents)
    return table
  end

  # exec executes the compiler pipeline up to the specified ending stage.
  def exec
    source_files = [] of SourceFile

    # Check that all of the paths exist.
    @paths.each do |path|
      if File.exists?(path)
        # JLS 2, sec 7.6 (page 155) says java files may also be
        # ".jav". I bet this is a secret test ;O.
        if !(/\.java?$/ =~ path)
          STDERR.puts "ERROR: path is not a .java or .jav file"
          exit 42
        end
        source_files.push(SourceFile.new(path))
      elsif Dir.exists?(path)
        Dir.glob("**/*.java").each do |file|
          source_files.push(SourceFile.new(file))
        end
      else
        STDERR.puts "ERROR: path #{path} does not exist"
        exit 2
      end
    end

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                               SCANNING                                  #
    #                                                                         #
    # Load each source file and scan them into tokens.                        #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    source_files.each { |file| file.read! }
    source_files.each { |file| do_scan!(file) }
    source_files.map &.debug_print(Stage::SCAN) if @verbose
    exit 0 if @end_stage == Stage::SCAN

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                                PARSING                                  #
    #                                                                         #
    # Load LALR(1) prediction table and parse tokens of each source file.     #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    @table = load_parse_table
    source_files.each { |file| do_parse!(@table, file) }
    source_files.map &.debug_print(Stage::PARSE) if @verbose
    exit 0 if @end_stage == Stage::PARSE


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                             SIMPLIFICATION                              #
    #                                                                         #
    # Simplify each parse tree into an abstract syntax tree.                  #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    source_files.each { |file| do_simplify!(file) }
    source_files.map &.debug_print(Stage::SIMPLIFY) if @verbose
    exit 0 if @end_stage == Stage::SIMPLIFY

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                                  WEEDING                                #
    #                                                                         #
    # Weed out any errors that could not be detected by parsing.              #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    source_files.each { |file| do_weed!(file) }
    source_files.map &.debug_print(Stage::WEED) if @verbose
    exit 0 if @end_stage == Stage::WEED
  end
end
