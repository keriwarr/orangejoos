at_exit { Crystal.restore_blocking_state }

require "./orangejoos/*"
require "./argparser"

# This entrypoint is provided just to provide the interface as desired
# for CS444. That is, only take filenames as input without any further
# arguments.
begin
  args = ArgParser.new(ARGV)
  Pipeline.new(args.table_file, args.paths, args.end_stage, args.verbose).exec
rescue ex : ArgumentError
  exit 1
rescue ex : PipelineError
  STDERR.puts ex
  exit 42
rescue ex : Exception
  STDERR.puts ex
  exit 2
end
