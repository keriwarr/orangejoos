# List of valid operators and their types.

# class OperatorSig
#   def initialize(@op : String, @input : Array(Typing::Type), @output : Typing::Type)
#   end
# end

# def shorthand_to_sigs(sh) : Array(OperatorSig)
#   sigs = [] of OperatorSig
#   return OperatorSig.new(sh[:op], sh[:input], sh[:output])
# end

# VALID_OPERATORS = [
#   # Numerical
#   # Numerical comparison
#   {op: ">", input: ["num", "num"], output: "bool"},
#   {op: "<", input: ["num", "num"], output: "bool"},
#   {op: "<=", input: ["num", "num"], output: "bool"},
#   {op: ">=", input: ["num", "num"], output: "bool"},
#   # Numerical equality
#   {op: "==", input: ["num", "num"], output: "bool"},
#   {op: "!=", input: ["num", "num"], output: "bool"},
#   # Numerical operations
#   ## Unary
#   {op: "-", input: ["num"], output: "num"},
#   {op: "+", input: ["num"], output: "num"},
#   ## Binary
#   {op: "+", input: ["num", "num"], output: "num"},
#   {op: "-", input: ["num", "num"], output: "num"},
#   {op: "/", input: ["num", "num"], output: "num"},
#   {op: "*", input: ["num", "num"], output: "num"},
#   {op: "%", input: ["num", "num"], output: "num"},

#   # Boolean
#   {op: "==", input: ["bool", "bool"], output: "bool"},
#   {op: "!=", input: ["bool", "bool"], output: "bool"},
#   {op: "!", input: ["bool"], output: "bool"},
#   {op: "&", input: ["bool", "bool"], output: "bool"},
#   {op: "|", input: ["bool", "bool"], output: "bool"},
#   {op: "^", input: ["bool", "bool"], output: "bool"},
#   {op: "&&", input: ["bool", "bool"], output: "bool"},
#   {op: "||", input: ["bool", "bool"], output: "bool"},
# ]
