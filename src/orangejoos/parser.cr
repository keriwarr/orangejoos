require "./lexeme.cr"
require "./compiler_errors.cr"
require "./lalr1_table.cr"
require "./parse_tree.cr"

COMMENT_TYPES = Set{Type::Comment, Type::MultilineComment, Type::JavadocComment}

# The Parser takes *input*, a list of lexemes, and produces the parse
# tree. It checks for the correct syntantical structure of the code
# during `parse()`. If the input does not conform, a SyntaxStageError is
# produced.
class Parser
  @state : Int32

  def initialize(@table : LALR1Table, input : Array(Lexeme))
    # Filter out any comment types from the input. These are ignored
    # during parsing.
    input = input.reject {|lexeme| COMMENT_TYPES.includes?(lexeme.typ)}

    # Transform the input into a deque, to allow peeking (via. push_to_front)
    @input = Deque(ParseNode).new(input)
    # Push a trailing EOF keyword for parsing.
    @input.push(Lexeme.new(Type::EOF, 0, ""))
    # The state always begins at 0.
    @state = 0
    # Stack of tokens.
    @stack = Deque(ParseNode).new
    # Stack of the state for each token.
    # FIXME(joey): Make the stack of tuples.
    @state_stack = Deque(Int32).new
  end

  # Generates a parse tree from the input the parser was provided.
  def parse : ParseTree
    lookahead = nil
    while lookahead != nil || @input.size > 0
      # When there is no next lookahead, shift the next value from the input.
      # We will only sitll have a lookahead during reductions.
      if lookahead.nil?
        lookahead = @input.first
        @input.shift
      end

      # Check if the action exists in the lookup table. If it does not,
      # then the program is invalid.
      if !@table.has_action(@state, lookahead.parse_token)
        raise ParseStageError.new("no next action for state=#{@state} token=#{lookahead.parse_token}")
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
      if action.typ == ActionType::Shift
        @stack.push(lookahead)
        @state_stack.push(@state)
        @state = action.state
        lookahead = nil
      elsif action.typ == ActionType::Reduce
        # Push the lookahead back to the head of the input.
        @input.unshift(lookahead)
        rule = @table.get_rule(action.state)
        # Recover the state of the latest item on the stack along with
        # reducing items off the stack.
        tokens = (0...rule.reduce_size).map { |tree| @state = @state_stack.pop; @stack.pop }
        node = ParseTree.new(rule.lhs, tokens.reverse)

        lookahead = node
      end
    end

    # FIXME(joey): Make sure there is only one parse item and it is a parse tree.
    node = @stack[0]
    if !node.is_a?(ParseTree)
      raise ParseStageError.new("Huzza")
    end
    return node
  end
end
