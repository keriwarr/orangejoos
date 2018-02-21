require "option_parser"

# haha nice meme dude
module Bruce
  BANNER = "Usage: joosc compile [arguments] [files...]\n" \
           "Stages:\n\tscan -> parse -> simplify -> weed -> ..."
end

# ArgParser parses options for the joosc compiler.
class ArgParser
  getter verbose    = false
  getter end_stage  = "all"   # default runs the entire pipeline
  getter paths      = [] of String
  getter table_file = "grammar/joos1w.lr1"

  def initialize(args : Array(String))
    OptionParser.parse(args) do |parser|
      parser.banner = Bruce::BANNER
      parser.on("-v", "--verbose", "show verbose logs") { @verbose = true }
      parser.on("-h", "--help", "show help") { puts parser; exit }
      parser.on("-t TABLE", "--table=TABLE",
        "specifies LALR1 prediction table file (required for parsing stage") do |path|
        @table_file = path
      end
      parser.on("-s STAGE", "--stage=STAGE", "compiler stage to stop execution at" ) do |stage|
        @end_stage = stage
      end
      parser.unknown_args { |args| @paths = args }
    end
  end
end
