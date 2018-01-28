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
    failure = false
    if !File.exists?(file)
      failure = true
      puts "ERROR: file #{file} does not exist"
    end
    if failure
      exit 1
    end
  end

  files.each do |file|
    contents = File.read(file)
    begin
      results = Scanner.new(contents.chars).scan
    rescue ex : ScanningError
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
else
  puts "Usage: orangejoos [command]

Commands:
  scan - parse a source file into lexemes"
  exit 1
end
