require "./lexeme.cr"
require "./ast.cr"
require "./lalr1_table.cr"
require "./parse_tree.cr"
require "./weeding.cr"

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
    if filename[0].ascii_number?
      filename = "_" + filename
    end

    # Replace all invalid name characters with underscores. Only ascii
    # letters, numbers, '$', and '_' are considered valid.
    cleaned_filename = ""
    new_word = true
    filename.chars.each do |c|
      if c.ascii_letter?
        if new_word
          new_word = false
          cleaned_filename += c.upcase
        else
          cleaned_filename += c
        end
      elsif c.ascii_number? || c == '$' || c == '_'
        new_word = true
        cleaned_filename += c
      else
        new_word = true
        cleaned_filename += "_"
      end
    end

    return cleaned_filename
  end
end

# The Pipeline executes the compiler pipeline.
class Pipeline
  @end_stage = ""
  @verbosity = false
  @table = uninitialized LALR1Table
  @table_file = ""
  @paths = [] of String

  # *args* are the CLI arguments.
  def initialize(args : Array(String))
    @parser = OptionParser.parse(args) do |parser|
      parser.banner = "Usage: orangejoos compile [arguments] [files...]
Stages:
  scan -> parse -> simplify -> weed -> ..."

      # Pipeline parse.
      parser.on("-s STAGE", "--stage=STAGE", "Specifies the compiler stage to stop execution at. (Required)") { |stage| @end_stage = stage.downcase }
      parser.on("-v", "--verbose", "Show verbose logs.") { @verbosity = true }
      parser.on("-h", "--help", "Show the help prompt.") { puts parser; exit }
      parser.unknown_args { |args| @paths = args }

      # Parse stage.
      parser.on("-t TABLE", "--table=TABLE", "Specifies the LALR1 prediction table file. (Required for Parse stage)") { |table| @table_file = table }
    end
  end

  def do_scan!(file : SourceFile)
    begin
      tokens = Scanner.new(file.contents.to_slice).scan
    rescue ex : ScanningStageError
      STDERR.puts "Failed to scan with exception: #{ex}"
      exit 42
    end

    # Search for Bad tokens.
    # FIXME(joey): Collect errors.
    tokens.each do |res|
      if res.typ == Type::Bad
        STDERR.puts "Failed to parse, got tokens: "
        STDERR.puts tokens
        exit 42
      end
    end

    file.tokens = tokens
    return tokens
  end

  def do_parse!(table : LALR1Table, file : SourceFile)
    begin
      parse_tree = Parser.new(table, file.tokens).parse
    rescue ex : ParseStageError
      STDERR.puts "Failed to parse with exception: #{ex}"
      exit 42
    end
    file.parse_tree = parse_tree
    return parse_tree
  end

  def do_simplify!(file : SourceFile)
    begin
     ast = Simplification.new.simplify(file.parse_tree).as(AST::File)
    rescue ex : SimplifyStageError
      STDERR.puts "Failed to simplify with exception: #{ex}"
      exit 42
    end
    file.ast = ast
    return ast
  end

  def do_weed!(file : SourceFile)
    begin
     Weeding.new(file.ast, file.class_name).weed
    rescue ex : WeedingStageError
      STDERR.puts "Found weeding error: #{ex}"
      exit 42
    end
  end

  def load_parse_table
    if @table_file == ""
      STDERR.puts @parser
      STDERR.puts "ERROR: no LALR1 table file was not provided"
      exit 1
    end

    # Check that the table file exists.
    if !File.exists?(@table_file)
      STDERR.puts "ERROR: file #{@table_file} does not exist"
      exit 1
    end

    table_contents = File.read_lines(@table_file)
    table = LALR1Table.new(table_contents)
    return table
  end

  def exec
    if @paths.size == 0
      STDERR.puts @parser
      STDERR.puts "ERROR: no paths were provided"
      exit 1
    end

    source_files = [] of SourceFile

    # Check that all of the paths exist.
    @paths.each do |path|
      if File.exists?(path)
        if !(/\.java?$/ =~ path)
          # JLS 2, sec 7.6 (page 155) says java files may also be
          # ".jav". I bet this is a secret test ;O.
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

    # Load each source file.
    source_files.each { |file| file.read! }
    # Scan the tokens of each source file.
    source_files.each { |file| do_scan!(file) }

    # XXX: debug print lexemes trees.
    source_files.each { |file| puts "=== FILE lexemes: #{file.path} ===\n#{file.tokens}" }

    if @end_stage == "scan"
      exit 0
    end

    # Load the LALR(1) prediction table.
    @table = load_parse_table

    # Parse the tokens of each source file.
    source_files.each { |file| do_parse!(@table, file) }

    # XXX: debug print parse trees.
    source_files.each { |file| puts "=== FILE parse tree: #{file.path} ===\n#{file.parse_tree.pprint}" }

    if @end_stage == "parse"
      exit 0
    end

    # Simplify the parse trees into abstract syntax trees.
    source_files.each { |file| do_simplify!(file) }

    if @end_stage == "simplify"
      exit 0
    end

    # XXX: debug print ast.
    source_files.each { |file| puts "=== FILE abstract syntax tree: #{file.path} ===\n#{file.ast.pprint}" }

    # Weed out any errors from parsing.
    source_files.each { |file| do_weed!(file) }

    if @end_stage == "weed"
      exit 0
    end

  end
end
