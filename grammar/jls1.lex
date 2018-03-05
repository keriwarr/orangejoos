# This grammar file is from the Java Language Spec 1.
# It specifies all of the tokens definitions, in a CFG-style.
# This was copied from JLS 1 chapter 3.10 - Literal Rules.
#
# If a statement has the suffix "?", it is optional.


RawInputCharacter:
  # any Unicode character

UnicodeInputCharacter:
  UnicodeEscape
  RawInputCharacter

UnicodeEscape:
  \ UnicodeMarker HexDigit HexDigit HexDigit HexDigit

UnicodeMarker:
  u
  UnicodeMarker u

InputCharacter:
  # but not CR or LF
  UnicodeInputCharacter

Separator: one of
  ( ) { } [ ] , .

Operator: one of
  = > < !
  == <= >= != && ||
  + - * / %

BooleanLiteral: one of
  true false

CharacterLiteral:
  ' SingleCharacter '
  ' EscapeSequence '

SingleCharacter:
  # but not ' or \
  InputCharacter

# The escape sequences are described in §3.10.6.
# As specified in §3.4, the characters CR and LF are never an InputCharacter
# they are recognized as constituting a LineTerminator.
# It is a compile - time error for the character following the SingleCharacter or
# EscapeSequence to be other than a '.
# It is a compile - time error for a line terminator to appear after the opening '
# and before the closing '.

Identifier:
  # but not a Keyword or BooleanLiteral or NullLiteral
  IdentifierChars

IdentifierChars:
  JavaLetter
  IdentifierChars JavaLetterOrDigit

JavaLetter:
  a
  # any Unicode character that is a Java letter(see below)

JavaLetterOrDigit:
  # any Unicode character that is a Java letter - or-digit(see below)
  # Letters and digits may be drawn from the entire Unicode character

# An integer literal may be expressed in decimal (base 10), hexadecimal
# (base 16), or octal(base 8)
IntegerLiteral:
  DecimalIntegerLiteral
  HexIntegerLiteral
  OctalIntegerLiteral

DecimalIntegerLiteral:
  DecimalNumeral IntegerTypeSuffix?

HexIntegerLiteral:
  HexNumeral IntegerTypeSuffix?

OctalIntegerLiteral:
  OctalNumeral IntegerTypeSuffix?

IntegerTypeSuffix: one of
  l L

DecimalNumeral:
  0
  NonZeroDigit Digits?

Digits:
  Digit
  Digits Digit

Digit:
  0
  NonZeroDigit

NonZeroDigit: one of
  1 2 3 4 5 6 7 8 9

HexNumeral:
  0 x HexDigit
  0 X HexDigit
  HexNumeral HexDigit

HexDigit: one of
  0 1 2 3 4 5 6 7 8 9 a b c d e f A B C D E F

OctalNumeral:
  0 OctalDigit
  OctalNumeral OctalDigit

OctalDigit: one of
  0 1 2 3 4 5 6 7

FloatingPointLiteral:
  Digits . Digits? ExponentPart? FloatTypeSuffix?
  . Digits ExponentPart? FloatTypeSuffix?
  Digits ExponentPart FloatTypeSuffix?
  Digits ExponentPart? FloatTypeSuffix

ExponentPart:
  ExponentIndicator SignedInteger

ExponentIndicator: one of
  e E

SignedInteger:
  Sign? Digits

Sign:
  -
  +

FloatTypeSuffix:
  f F d D

NullLiteral:
  null

StringLiteral:
  " StringCharacters? "

StringCharacters:
  StringCharacter
  StringCharacters StringCharacter

StringCharacter:
  # but not " or \
  InputCharacter
  EscapeSequence

EscapeSequence:
  # \u0008: backspace BS
  \ b
  # \u0009: horizontal tab HT
  \ t
  # \u000a: linefeed LF
  \ n
  # \u000c: form feed FF
  \ f
  # \u000d: carriage return CR
  \ r
  # \u0022: double quote"
  \ "
  # \u0027: single quote '
  \ '
  # \u005c: backslash \
  \ \
  # \u0000 to \u00ff: from octal value
  OctalEscape

OctalEscape:
  \ OctalDigit
  \ OctalDigit OctalDigit
  \ ZeroToThree OctalDigit OctalDigit

ZeroToThree: one of
  0 1 2 3

