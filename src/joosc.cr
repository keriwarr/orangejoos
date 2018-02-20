STDIN.blocking = true
STDOUT.blocking = true
STDERR.blocking = true

require "./orangejoos/*"
require "./argparser"

# This entrypoint is provided just to provide the interface as desired
# for CS444. That is, only take filenames as input without any further
# arguments.
args = ArgParser.new(ARGV)
Pipeline.new(args.table_file, args.paths, args.end_stage, args.verbose).exec
