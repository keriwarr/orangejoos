enum Type
  Keyword
  Separator
  Operator
  Number
  Keyword
  CharacterLiteral
  StringLiteral

  Bad
end

BOOL_LITERALS = Set{
  "true",
  "false"
}

NULL_LITERALS = Set{
  "null"
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

  def initialize(typ: nil, len: nil, sem: nil)
    @typ = typ
    @len = len
    @sem = sem
  end

end
