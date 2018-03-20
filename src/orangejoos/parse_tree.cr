require "./lexeme.cr"

class ParseNodes
  def initialize(inp : Array(ParseNode))
    @arr = inp
  end

  def initialize(inp : ParseNode)
    @arr = Array(ParseNode).new
    @arr.push(inp)
  end

  def to_a
    return @arr
  end

  def first
    return @arr.first
  end

  def size
    return @arr.size
  end

  def get_trees(name : String) : Array(ParseTree)
    trees = [] of ParseTree
    @arr.each do |node|
      if node.is_a?(ParseTree) && node.name == name
        trees.push(node)
      end
    end
    return trees
  end

  # Gets the child tree of the specified name, if only one node has the
  # name. Nil may be returned if no tree is found.
  def get_tree(name : String) : ParseTree?
    trees = self.get_trees(name)
    if trees.size > 1
      raise Exception.new("expected 1 tree, got: #{trees.size}")
    end
    if trees.size == 0
      return nil
    end
    return trees.first
  end

  # Gets the child tree of the specified name, if only one node has the
  # name. An exception is raised if the node was not found.
  def get_tree!(name : String) : ParseTree
    res = self.get_tree(name)
    if res.nil?
      elems = @arr.map { |node| node.parse_token }
      raise Exception.new("unexpected nil: looking for name=#{name} self=#{elems}")
    end
    return res
  end
end

# A ParseTree is a parse node that represents a non-terminal rule.
# It consists of a list of *tokens* that are the RHS of the rule.
class ParseTree < ParseNode
  getter tokens : ParseNodes
  getter name : String

  def initialize(@name : String, tokens : Array(ParseNode))
    @tokens = ParseNodes.new(tokens)
  end

  def initialize(@name : String, token : ParseNode)
    @tokens = ParseNodes.new(token)
  end

  # Implements `ParseNode.parse_token()`.
  def parse_token
    @name
  end

  # Implements `ParseNode.pprint()`.
  def pprint(depth : Int32 = 0)
    indent = "  " * depth
    children = @tokens.to_a.map { |tok| tok.pprint(depth + 1) }.join("\n")
    return "#{indent}#{@name}\n#{children}"
  end

  def to_s
    return "#{@name}"
  end
end
