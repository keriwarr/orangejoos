require "./lexeme.cr"
require "./compiler_errors.cr"
require "./lalr1_table.cr"

# A ParseTree is a parse node that represents a non-terminal rule.
# It consists of a list of *tokens* that are the RHS of the rule.
# TODO(joey): Move the parse tree into a separate file to split out
# dependencies.
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
end

# The Parser takes *input*, a list of lexemes, and produces the parse
# tree. It checks for the correct syntantical structure of the code
# during `parse()`. If the input does not conform, a SyntaxStageError is
# produced.
class Parser
  @state : Int32

  def initialize(@table : LALR1Table, input : Array(Lexeme))
    # Transform the input into a deque, to allow peeking (via. push_to_front)
    @input = Deque(ParseNode).new(input)
    # The state always begins at 0.
    @state = 0
    # Stack of tokens.
    @stack = Deque(ParseNode).new
    # Stack of the state for each token.
    # FIXME(joey): Make the stack of tuples.
    @state_stack = Deque(Int32).new
  end

  # Generates a parse tree from the input the parser was provided.
  def parse
    lookahead = nil
    while lookahead != nil || @input.size > 0
      # When there is no next lookahead, shift the next value from the input.
      # We will only sitll have a lookahead during reductions.
      if lookahead.nil?
        lookahead = @input.first
        @input.shift
      end

      # Do a lookup in the prediction table with {State, ParseToken}.
      action = @table.get_next_action(@state, lookahead.parse_token)

      # Do either a reduce or a shift.
      #
      # For shift: take the lookahead and "read" it and then put it
      # on the stack. We transition to the next state denoted by the
      # lookahead.
      #
      # For reduce: push the lookahead back onto the unread input. Then
      # look up the reduction rule and reduce the amount of RHS tokens.
      # Finally, consider the newly produced LHS as the lookahead to do
      # the next state transition. The state will be the state of the
      # most recently popped stack element.
      #
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
        node = ParseTree.new(rule.lhs, tokens)

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
