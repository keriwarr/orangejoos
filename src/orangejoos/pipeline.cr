require "./lexeme.cr"
require "./lalr1_table.cr"
require "./parse_tree.cr"

class SourceFile
  property! tokens : Array(Lexeme)
  property! parse_tree : ParseTree

  getter! path : String
  getter! contents : String

  def initialize(@path : String)
  end

  def read!
    @contents = File.read(path)
    return contents
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
  scan -> parse -> ..."

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
      tokens = Scanner.new(file.contents.chars).scan
    rescue ex : ScanningStageError
      puts "Failed to parse with exception: #{ex}"
      exit 42
    end

    # Search for Bad tokens.
    # FIXME(joey): Collect errors.
    tokens.each do |res|
      if res.typ == Type::Bad
        puts "Failed to parse, got tokens: "
        puts tokens
        exit 42
      end
    end

    file.tokens = tokens
    return tokens
  end

  def do_parse!(table : LALR1Table, file : SourceFile)
    parse_tree = Parser.new(table, file.tokens).parse
    file.parse_tree = parse_tree
    return parse_tree
  end

  def load_parse_table
    if @table_file == ""
      puts @parser
      puts "ERROR: no LALR1 table file was not provided"
      exit 1
    end

    # Check that the table file exists.
    if !File.exists?(@table_file)
      puts "ERROR: file #{@table_file} does not exist"
      exit 1
    end

    table_contents = File.read_lines(@table_file)
    table = LALR1Table.new(table_contents)
    return table
  end

  def exec
    if @paths.size == 0
      puts @parser
      puts "ERROR: no paths were provided"
      exit 1
    end

    source_files = [] of SourceFile

    # Check that all of the paths exist.
    @paths.each do |path|
      if File.exists?(path)
        source_files.push(SourceFile.new(path))
      elsif Dir.exists?(path)
        Dir.glob("**/*.java").each do |file|
          source_files.push(SourceFile.new(file))
        end
      else
        puts "ERROR: path #{path} does not exist"
        exit 1
      end
    end

    # Load each source file.
    source_files.each { |file| file.read! }
    # Scan the tokens of each source file.
    source_files.each { |file| do_scan!(file) }

    if @end_stage == "scan"
      exit 0
    end

    # Load the LALR(1) prediction table.
    @table = load_parse_table

    # Parse the tokens of each source file.
    source_files.each { |file| do_parse!(@table, file) }

    # XXX: debug print parse trees.
    source_files.each { |file| puts "=== FILE: #{file.path} ===\n#{file.parse_tree.pprint}" }
  end
end
