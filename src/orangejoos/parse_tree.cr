require "./lexeme.cr"

# A ParseTree is a parse node that represents a non-terminal rule.
# It consists of a list of *tokens* that are the RHS of the rule.
class ParseTree < ParseNode
  @tokens : Array(ParseNode)
  getter name : String

  def initialize(@name : String, @tokens : Array(ParseNode))
  end

  def initialize(@name : String, token : ParseNode)
    @tokens = Array(ParseNode).new(token)
  end

  # Implements `ParseNode.parse_token()`.
  def parse_token
    @name
  end

  # Implements `ParseNode.pprint()`.
  def pprint(depth : Int32 = 0)
    indent = "  " * depth
    children = @tokens.map { |tok| tok.pprint(depth + 1) }.join("\n")
    return "#{indent}#{@name}\n#{children}"
  end

  def to_s
    return "#{@name}"
  end
end
