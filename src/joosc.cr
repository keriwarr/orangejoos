require "./orangejoos/*"
require "option_parser"

# This entrypoint is provided just to provide the interface as desired
# for CS444. That is, only take filenames as input without any further
# arguments.

# Default arguments provided when compiling.
arguments = [
  "-t",
  "grammar/joos1w.lr1",
]

arguments = arguments.concat(ARGV)

pipeline = Pipeline.new(arguments)
pipeline.exec
