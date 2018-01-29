enum Type
  Keyword
  Identifier
  Separator
  Operator
  NumberLiteral
  CharacterLiteral
  StringLiteral

  Bad
end

OpEQ     = "=="
OpASSIGN = "="
OpNEQ    = "!="
OpNOT    = "!"
OpADD    = "+"
OpSUB    = "-"
OpMULT   = "*"
OpDIV    = "/"
OpMOD    = "%"
OpLEQ    = "<="
OpLT     = "<"
OpGEQ    = ">="
OpGT     = ">"
OpAND    = "&&"
OpEAND   = "&"
OpOR     = "||"
OpEOR    = "|"

LPAREN  = "("
RPAREN  = ")"
LBRACK  = "["
RBRACK  = "]"
LBRACE  = "{"
RBRACE  = "}"
SEMICOL = ";"
COMMA   = ","
DOT     = "."

BOOL_LITERALS = Set{
  "true",
  "false",
}

NULL_LITERALS = Set{
  "null",
}

KEYWORDS = Set{
  # Types.
  "boolean",
  "byte",
  "int",
  "short",
  "void",
  "char",

  # Modifiers.
  "abstract",
  "private",
  "protected",
  "public",
  "final",
  "static",
  "while",

  # Classes
  "interface",
  "class",
  "extends",
  "implements",
  "native",
  "new",
  "package",

  # Control flow
  "if",
  "else",
  "return",
  "for",

  # Misc.
  "import",
  "instanceof",
}

# A ParseNode is an abstract type for nodes that are operated on during
# the parse stage.
abstract class ParseNode
  # Generates a pretty printable string representation of the ParseNode.
  abstract def pprint(depth : Int32)
end

# A Lexeme is an individual token. Lexemes are produced during the
# scanning phase and are used during parsing. A Lexeme is a ParseNode,
# representing the leafs of the parse tree.
#
# - The *typ* of a Lexeme represents the token category (refer to Type).
# - The *size* of a Lexeme represents the size of the Lexeme in source
#   code. For string or character literals the size will be larger than
#   the body of the token due to surrounding quotes and escaped
#   charaters.
# - The *sem* is the semantic body of the token. It is the scanned
#   content.
class Lexeme < ParseNode
  getter typ : Type
  getter size : Int32
  getter sem : String

  def initialize(@typ : Type, @size : Int32, @sem : String)
  end

  def to_s
    # TODO(joey): Handle cases for literals. Ideally, the case
    # statements in Parser.parse are moved to an abstract fcn on
    # ParseNode.
    @sem
  end

  # Implements ParseNode.pprint.
  def pprint(depth : Int32 = 0)
    indent = "  " * depth
    return "#{indent}#{@typ} #{@size} #{@sem}"
  end
end
