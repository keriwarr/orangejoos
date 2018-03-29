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


FLATTEN_EXPR_TREES = Set.new(["ConditionalOrExpression",
         "ConditionalAndExpression",
         "InclusiveOrExpression",
         "AndExpression",
         "EqualityExpression",
         "RelationalExpression",
         "AdditiveExpression",
         "MultiplicativeExpression"])

# For flattening.
enum Marker
  START, STOP
end

module ParseSimplification
  # Flattens structures that contain no information. Examples of this
  # include the following:
  #
  # TODO: (joey) 1) Trees representing lists of items.
  #
  #    ClassBodyDeclarations
  #      ClassBodyDeclarations
  #        ClassBodyDeclarations
  #          ClassBodyDeclarations
  #            ClassBodyDeclarations
  #
  # 2) Intermediary Expressions nodes only for parsing precedence.
  #
  #    AndExpression
  #      EqualityExpression
  #        RelationalExpression
  #          AdditiveExpression
  #            AdditiveExpression
  #              MultiplicativeExpression
  #                UnaryExpression
  #
  def self.flatten_tree(tree : ParseTree) : ParseTree
    # The structure of the stacks is the follow, if we have expanded a
    # node _parent_ into 3 children:
    #
    #   working_stack:
    #     Marker::START, child 1, child 2, child 2, Marker::END
    #
    #   waiting_stack:
    #     parent
    #
    # We process the nodes from the working stack to the waiting stack,
    # expanding it if possible and pushing it to the waiting stack.
    working_stack = Deque(ParseNode | Marker).new([tree])
    waiting_stack = Deque(ParseNode | Marker).new()

    # Go through items in a stack-like manner. Either:
    # 1) Process the `working_stack` which contains nodes that need
    #    to be processed.
    # 2) Process the `waiting_stack` which has fully processed nodes,
    #    re-packaging the trees. It is only processed once there is a
    #    `Marker::START` at the end of the stack. Note that it is START
    #    as everything has been reversed.
    while working_stack.size > 0 || waiting_stack.size > 1
      # See if we can process the `waiting_stack`, i.e. if the last
      # token is an end.
      if waiting_stack.size > 0 && waiting_stack.last == Marker::START
        # Pop off Marker::START.
        waiting_stack.pop
        children = [] of ParseNode
        while waiting_stack.last != Marker::STOP
          children.push(waiting_stack.pop.as(ParseNode))
        end
        # Pop off Marker::STOP.
        waiting_stack.pop
        # Pop off the parent, replace its children, and put it back on
        # the stack.
        parent = waiting_stack.pop.as(ParseTree)
        parent.tokens = ParseNodes.new(children)
        waiting_stack.push(parent)
        next
      end

      next_item = working_stack.pop
      if next_item.is_a?(Marker)
        waiting_stack.push(next_item)
      elsif next_item.is_a?(Lexeme)
        waiting_stack.push(next_item.as(ParseNode))
      elsif next_item.is_a?(ParseTree)
        # Check if this node can be reduced.
        if can_reduce(next_item)
           # Instead of adding the item to the `waiting_stack` we reduce
           # it and place the reduced result back onto the
           # `working_stack` to continue processing it.
          item = reduce_tree(next_item)
          working_stack.push(item)
        else
          # Put the current item onto the `waiting_stack`.
          waiting_stack.push(next_item)
          # Add the children onto the `working_stack`. Additionally,
          # put start and end markers around them.
          # NOTE: after processing them, they will be in reverse order.
          # This is desirable, because we then go through the
          # waiting_stack in reverse order.
          working_stack.push(Marker::START)
          next_item.tokens.to_a.each {|i| working_stack.push(i)}
          working_stack.push(Marker::STOP)
        end
      else raise Exception.new("unexpected case: node=#{next_item}")
      end
    end

    return waiting_stack.pop.as(ParseTree)
  end

  def self.can_reduce(tree : ParseTree) : Bool
    FLATTEN_EXPR_TREES.includes?(tree.name) && tree.tokens.size == 1
  end

  def self.reduce_tree(tree : ParseTree) : ParseTree
    if FLATTEN_EXPR_TREES.includes?(tree.name)
      return tree.tokens.first.as(ParseTree)
    else
      raise Exception.new("unhandled")
    end
  end
end
