# Type are the categories of Lexemes.
enum Type
  # Keywords are reserved identifiers that have a specific
  # meaning to the language. For example, "for", "private", ...
  Keyword
  # Identifiers are words that refer to items such as class names,
  # package names, variables, and more.
  Identifier
  # Separators is a bucket for tokens which cause separation. This
  # includes the typical brackets along with dots, semicolons, and commas.
  Separator
  # Operators are all unary or binary operators, including assignment.
  Operator
  # Comment ...
  Comment
  # MultilineComment ...
  MultilineComment
  # JavadocComment ...
  JavadocComment
  # Number literals are integers.
  NumberLiteral
  # Character literals are single letter literals.
  CharacterLiteral
  # String literals...
  StringLiteral
  # EOF is a special type to denote the end-of-file during parsing.
  EOF
  # BAD is badddd
  Bad
end

# Operators are all of the supported operators.
module Operator
  EQ     = "=="
  ASSIGN = "="
  NEQ    = "!="
  NOT    = "!"
  ADD    = "+"
  SUB    = "-"
  MULT   = "*"
  DIV    = "/"
  MOD    = "%"
  LEQ    = "<="
  LT     = "<"
  GEQ    = ">="
  GT     = ">"
  AND    = "&&"
  OR     = "||"
  # EAND is an eager AND.
  EAND = "&"
  # EOR is an eager OR.
  EOR = "|"
end

module Separator
  LPAREN  = "("
  RPAREN  = ")"
  LBRACK  = "["
  RBRACK  = "]"
  LBRACE  = "{"
  RBRACE  = "}"
  SEMICOL = ";"
  COMMA   = ","
  DOT     = "."
end

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

  # Other keywords that are not used in Joos1W but are forbidden
  "goto",
  "synchronized",
  "volatile",
  "float",
  "double",
  "long",
  "super",
  "this",
}

# A ParseNode is an abstract type for nodes that are operated on during
# the parse stage.
abstract class ParseNode
  # Generates a pretty printable string representation of the ParseNode.
  abstract def pprint(depth : Int32)

  # Gets the parse token representation of a node, as it appears in the
  # prediction table. This is used during the parse stage for prediction
  # table lookups.
  abstract def parse_token : String
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

  # Implements `ParseNode.parse_token()`.
  # Fetches the parse token string. It is one of:
  # - Literal or identifier, where the semantic definition is not
  #   required. Denoted with "LEXEME(Type)".
  # - Terminal tokens. e.g. a keyword, "else", or an operator "+"
  def parse_token
    case @typ
    when Type::Identifier then "LEXEME(Identifier)"
      # EOF is able to be represented as "EOF" as this does not conflict
      # with any other rules.
    when Type::EOF              then "EOF"
    when Type::Keyword          then @sem
    when Type::Operator         then @sem
    when Type::Separator        then @sem
    when Type::NumberLiteral    then "LEXEME(NumberLiteral)"
    when Type::StringLiteral    then "LEXEME(StringLiteral)"
    when Type::CharacterLiteral then "LEXEME(CharacterLiteral)"
    when Type::Comment then "COMMENT"
    when Type::MultilineComment then "MULTILINECOMMENT"
    when Type::JavadocComment then "JAVADOC"
      # ??, all other types which should be none of them.
    else @sem
    end
  end

  def to_s
    # TODO(joey): Handle cases for literals. Ideally, the case
    # statements in Parser.parse are moved to an abstract fcn on
    # ParseNode.
    @sem
  end

  # Implements `ParseNode.pprint()`.
  def pprint(depth : Int32 = 0)
    indent = "  " * depth
    return "#{indent}#{@typ} #{@size} #{@sem}"
  end
end
