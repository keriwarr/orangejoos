enum Type
  Keyword
  Identifier
  Separator
  Operator
  NumberLiteral
  CharLiteral
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

# TODO(joey): Not sure if brace and bracket are the correct names.
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

class Lexeme
  def initialize(typ : Type, len : Int32, sem : String)
    @typ = typ
    @len = len
    @sem = sem
  end

  def size
    @len
  end

  def typ
    @typ
  end

  def to_s
    return "#{@typ} #{@len} #{@sem}"
  end
end
