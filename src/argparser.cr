require "option_parser"

{% if flag?(:A2) %}
END_STAGE = Stage::NAME_RESOLUTION
{% elsif flag?(:A3) %}
END_STAGE = Stage::ALL
{% elsif flag?(:A1) %}
END_STAGE = Stage::WEED
{% elsif flag?(:A_NONE) %}
END_STAGE = Stage::ALL
{% else %}
Compilation error: unexpected assignment
{% end %}

# haha nice meme dude
module Bruce
  BANNER = "Usage: joosc compile [arguments] [files...]\n" \
           "Stages:\n\tscan -> parse -> simplify -> weed -> ..."
end

# ArgParser parses options for the joosc compiler.
class ArgParser
  getter verbose    : Bool   = false
  getter end_stage  : Stage  = END_STAGE
  getter paths               = [] of String
  getter table_file : String = "grammar/joos1w.lr1"

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
        @end_stage = Stage.get(stage)
      end
      parser.unknown_args { |args| @paths = args }
    end
  end
end
