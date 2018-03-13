at_exit { Crystal.restore_blocking_state }

require "./orangejoos/*"
require "./argparser"

# This entrypoint is provided just to provide the interface as desired
# for CS444. That is, only take filenames as input without any further
# arguments.
begin
  args = ArgParser.new(ARGV)
  Pipeline.new(args.table_file, args.paths, args.end_stage, args.verbose, args.use_stdlib).exec
rescue ex : ArgumentError
  STDERR.puts ex
  exit 42
rescue ex : WeedingStageError
  STDERR.puts "Weeding Stage Error: #{ex}"
  STDERR.puts "#{ex.inspect_with_backtrace}"
  exit 42
rescue ex : NameResolutionStageError
  STDERR.puts "Name resolution error: #{ex}"
  STDERR.puts "#{ex.inspect_with_backtrace}"
  exit 42
rescue ex : TypeCheckStageError
  STDERR.puts "Found type check error: #{ex}"
  STDERR.puts "#{ex.inspect_with_backtrace}"
  exit 42
rescue ex : CompilerError
  STDERR.puts ex.inspect_with_backtrace
  exit 42
rescue ex : Exception
  STDERR.puts ex.inspect_with_backtrace
  exit 42 # TODO(slnt) exit differently if verbose specifed?
end
