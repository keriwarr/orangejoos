STDIN.blocking = true
STDOUT.blocking = true
STDERR.blocking = true

require "./orangejoos/*"
require "./argparser"

case ARGV[0]?
when "compile"
  begin
    args = ArgParser.new(ARGV)
    Pipeline.new(args.table_file, args.paths, args.end_stage, args.verbose).exec
  rescue ex : Exception
    STDERR.puts "Compiler pipeline failed to complete: #{ex.message}"
  end
else
  STDERR.puts "Usage: orangejoos [command]

Commands:
  compile - compiles source code"
  exit 1
end
