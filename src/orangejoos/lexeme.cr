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

  # ???
  "import",
  "instanceof",
}

abstract class ParseTree
  abstract def pprint(depth : Int32)
end

class Lexeme < ParseTree
  getter typ : Type
  getter size : Int32
  getter sem : String

  def initialize(@typ : Type, @size : Int32, @sem : String)
  end

  def to_s
    # FIXME(joey): Handle cases for literals.
    @sem
  end

  def pprint(depth : Int32 = 0)
    indent = "  " * depth
    return "#{indent}#{@typ} #{@size} #{@sem}"
  end
end
