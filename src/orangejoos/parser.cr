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
    input = input.reject { |lexeme| COMMENT_TYPES.includes?(lexeme.typ) }

    # Transform the input into a deque, to allow peeking (via. push_to_front)
    @input = Deque(ParseNode).new(input)
    # Push a trailing EOF keyword for parsing.
    @input.push(Lexeme.new(Type::EOF, 0, ""))
    # The state always begins at 0.
    @state = 0
    # Stack of the tokens and state.
    @stack = Deque(Tuple(ParseNode, Int32)).new
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
        stack = @stack.map { |s, _| s.pprint }.join("\n=== STACK ITEM ===\n")
        raise ParseStageError.new("no next action for state=#{@state} token=#{lookahead.parse_token} parsenode=#{lookahead.inspect}\n=== STACK ===\n=== STACK ITEM ===\n#{stack}")
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
        @stack.push(Tuple.new(lookahead, @state))
        @state = action.state
        lookahead = nil
      elsif action.typ == ActionType::Reduce
        # Push the lookahead back to the head of the input.
        @input.unshift(lookahead)
        rule = @table.get_rule(action.state)
        # Recover the state of the latest item on the stack along with
        # reducing items off the stack.
        tokens = (0...rule.reduce_size).map { |tree| token, @state = @stack.pop; token }
        node = ParseTree.new(rule.lhs, tokens.reverse)

        lookahead = node
      end
    end

    # Check that there are only two items on the stack. The second should be an EOF.
    # TODO: (joey) actually check for an EOF.
    if @stack.size != 2
      raise Exception.new("parsing error: more than one item on the stack. size=#{@stack.size} stack=#{@stack}")
    end
    node = @stack[0][0]
    if !node.is_a?(ParseTree)
      raise ParseStageError.new("Huzza")
    end
    return node
  end
end
