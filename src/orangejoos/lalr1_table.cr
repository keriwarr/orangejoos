enum ActionType
  Reduce
  Shift
end

class Action
  getter typ : ActionType
  getter state : Int32

  def initialize(@typ : ActionType, @state : Int32)
  end

  def to_s
    return "#{@typ} #{@state}"
  end
end

class Rule
  getter lhs : String
  getter rhs : String

  def initialize(@lhs : String, @rhs : String)
  end

  def reduce_size
    @rhs.split(" ").size
  end

  def to_s
    return "#{@lhs} => #{@rhs}"
  end
end

class LALR1Table
  getter start : String
  @start : String

  def initialize(@input : Array(String))
    @transitions = Hash(Tuple(Int32, String), Action).new
    @rules = Array(Rule).new

    # read terminals
    terminals_count = @input[0].to_i
    @terminals = Set(String).new(@input[1, terminals_count])
    @input = @input[1 + terminals_count, @input.size]

    # read nonterminals
    nonterminals_count = @input[0].to_i
    @nonterminals = Set(String).new(@input[1, nonterminals_count])
    @input = @input[1 + nonterminals_count, @input.size]

    # read start : String
    @start = @input[0]
    @input.shift

    # read rules
    rules_count = @input[0].to_i
    rule_lines = @input[1, rules_count]
    rule_lines.each do |rule|
      lhs = rule.split(" ")[0]
      rhs = rule[lhs.size, rule.size].strip
      @rules.push(Rule.new(lhs, rhs))
    end
    @input = @input[1 + rules_count, @input.size]

    # read transitions
    state_count = @input[0].to_i
    transitions_count = @input[1].to_i
    transition_lines = @input[2, transitions_count]
    transition_lines.each do |transition|
      t = transition.split(" ")
      from_state = t[0].to_i
      lookahead = t[1]
      action_typ = t[2]
      to_state = t[3].to_i
      action = nil
      if action_typ == "reduce"
        action = Action.new(ActionType::Reduce, to_state)
      elsif action_typ == "shift"
        action = Action.new(ActionType::Shift, to_state)
      else
        raise "Uh oh, unknown action_typ=#{action_typ}"
      end
      key = Tuple(Int32, String).new(from_state, lookahead)
      @transitions[key] = action
    end
    @input = @input[2 + transitions_count, @input.size]

    if @input.size > 0
      raise Exception.new("ERROR: remaining input on table, #{@input.size} lines: #{@input}")
    end
  end

  def get_rule(idx : Int32)
    @rules[idx]
  end

  def get_next_action(state : Int32, lookahead : String)
    key = Tuple(Int32, String).new(state, lookahead)
    return @transitions.fetch(key)
  end
end
