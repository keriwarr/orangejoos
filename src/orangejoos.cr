require "./orangejoos/*"
require "option_parser"

case ARGV[0]?
when "scan"
  files = [] of String
  parser = OptionParser.parse(ARGV[1, ARGV.size]) do |parser|
    parser.banner = "Usage: orangejoos scan [arguments] [files...]"
    parser.on("-h", "--help", "Show this help") { puts parser; exit }
    parser.unknown_args { |args| files = args }
  end
  if files.size == 0
    puts parser
    puts "ERROR: no files were provided"
    exit 1
  end

  # Check that all of the files exist.
  # TODO(joey): Also support scanning folders.
  files.each do |file|
    if !File.exists?(file)
      puts "ERROR: file #{file} does not exist"
      exit 1
    end
  end

  files.each do |file|
    contents = File.read(file)
    begin
      results = Scanner.new(contents.chars).scan
    rescue ex : ScanningStageError
      puts "Failed to parse with exception: #{ex}"
      exit 42
    end

    # Search for Bad tokens.
    results.each do |res|
      if res.typ == Type::Bad
        puts "Failed to parse, got tokens: "
        puts results
        exit 42
      end
    end

    results.each do |res|
      puts res.to_s
    end
  end
when "readtable"
  files = [] of String
  parser = OptionParser.parse(ARGV[1, ARGV.size]) do |parser|
    parser.banner = "Usage: orangejoos readtable [arguments] file"
    parser.on("-h", "--help", "Show this help") { puts parser; exit }
    parser.unknown_args { |args| files = args }
  end
  if files.size == 0
    puts parser
    puts "ERROR: no files were provided"
    exit 1
  elsif files.size > 1
    puts parser
    puts "ERROR: only one lr1 file can be provided"
    exit 1
  end
  file = files[0]

  # Check that the file exists.
  if !File.exists?(file)
    puts "ERROR: file #{file} does not exist"
    exit 1
  end

  contents = File.read_lines(file)
  begin
    table = LALR1Table.new(contents)
    puts table
  rescue ex : Exception
    puts "Failed to set up table with exception: #{ex}"
    exit 42
  end
when "parse"
  files = [] of String
  table_file = ""
  parser = OptionParser.parse(ARGV[1, ARGV.size]) do |parser|
    parser.banner = "Usage: orangejoos scan [arguments] [files...]"
    parser.on("-t TABLE", "--table=TABLE", "Specifies the LALR1 prediction table file") { |table| table_file = table }
    parser.on("-h", "--help", "Show this help") { puts parser; exit }
    parser.unknown_args { |args| files = args }
  end
  if files.size == 0
    puts parser
    puts "ERROR: no files were provided"
    exit 1
  end
  if table_file == ""
    puts parser
    puts "ERROR: no LALR1 table file was not provided"
    exit 1
  end

  # Check that the table file exists.
  if !File.exists?(table_file)
    puts "ERROR: file #{table_file} does not exist"
    exit 1
  end

  table_contents = File.read_lines(table_file)
  table = LALR1Table.new(table_contents)

  # Check that all of the files exist.
  # TODO(joey): Also support scanning folders.
  files.each do |file|
    if !File.exists?(file)
      puts "ERROR: file #{file} does not exist"
      exit 1
    end
  end

  files.each do |file|
    contents = File.read(file)
    begin
      results = Scanner.new(contents.chars).scan
    rescue ex : ScanningStageError
      puts "Failed to parse with exception: #{ex}"
      exit 42
    end

    # Search for Bad tokens.
    results.each do |res|
      if res.typ == Type::Bad
        puts "Failed to parse, got tokens: "
        puts results
        exit 42
      end
    end

    parse_trees = Parser.new(table, results).parse
    parse_trees.each { |tree| puts tree.pprint }
    # puts parse_tree.pprint
  end
else
  puts "Usage: orangejoos [command]

Commands:
  scan - reads a source file into lexemes
  readtable - reads an lr1 prediction table
  parse - parses the source file into a parse tree"
  exit 1
end
