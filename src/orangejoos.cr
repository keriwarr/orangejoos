require "./orangejoos/*"
require "option_parser"

case ARGV[0]?
when "compile"
  pipeline = Pipeline.new(ARGV[1, ARGV.size])
  pipeline.exec
else
  puts "Usage: orangejoos [command]

Commands:
  compile - compiles source code"
  exit 1
end
