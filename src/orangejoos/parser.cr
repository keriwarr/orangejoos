require "./lexeme.cr"
require "./lalr1_table.cr"

class ParseNode < ParseTree
  @tokens : Array(ParseTree)
  getter name : String

  def initialize(@name : String, @tokens : Array(ParseTree))
  end

  def initialize(@name : String, token : ParseTree)
    @tokens = Array(ParseTree).new(token)
  end

  def pprint(depth : Int32 = 0)
    indent = "  " * depth
    children = @tokens.map { |tok| tok.pprint(depth + 1) }.join("\n")
    return "#{indent}#{@name}\n#{children}"
  end
end

class Parser
  @state : Int32

  def initialize(@table : LALR1Table, input : Array(Lexeme))
    # Transform the input into a deque, to allow peeking (via. push_to_front)
    @input = Deque(ParseTree).new(input)
    # The state always begins at 0.
    @state = 0
    # Stack of tokens.
    @stack = Deque(ParseTree).new
    # Stack of the state for each token.
    # FIXME(joey): Make the stack of tuples.
    @state_stack = Deque(Int32).new
  end

  def parse
    lookahead = nil
    while lookahead != nil || @input.size > 0
      # When there is no next lookahead, shift the next value from the input.
      # We will only sitll have a lookahead during reductions.
      if lookahead.nil?
        lookahead = @input.first
        @input.shift
      end

      if lookahead.is_a?(ParseNode)
        lookahead_str = lookahead.name
      elsif lookahead.is_a?(Lexeme)
        lookahead_str = case lookahead.typ
                        when Type::Identifier       then "LEXEME(Identifier)"
                        when Type::Keyword          then lookahead.sem
                        when Type::NumberLiteral    then "LEXEME(NumberLiteral)"
                        when Type::StringLiteral    then "LEXEME(StringLiteral)"
                        when Type::CharacterLiteral then "LEXEME(CharacterLiteral)"
                          # ??
                        else lookahead.sem
                        end
      else
        raise Exception.new("Unexpected")
        lookahead_str = ""
      end

      action = @table.get_next_action(@state, lookahead_str)
      # puts "For {#{@state}, \"#{lookahead.to_s}\"} got action=#{action.to_s}"
      if action.typ == ActionType::Shift
        @stack.push(lookahead)
        @state_stack.push(@state)
        @state = action.state
        lookahead = nil
      elsif action.typ == ActionType::Reduce
        # Push the lookahead back to the head of the deque.
        @input.insert(0, lookahead)
        rule = @table.get_rule(action.state)
        # Recover the state of the latest item on the stack along with
        # reducing items off the stack.
        tokens = (0...rule.reduce_size).map { |tree| @state = @state_stack.pop; @stack.pop }
        node = ParseNode.new(rule.lhs, tokens)
        @stack.push(node)

        # puts "Rule ##{action.state}, reduce size #{rule.reduce_size}: #{rule.to_s}"
        # puts "Tokens #{tokens}"
        lookahead = node
      end
    end

    # puts "Stack: #{@stack}"
    # puts "State: #{@state}"
    # puts "Input: #{@input}"
    # puts @stack.size
    return @stack.to_a
  end
end
