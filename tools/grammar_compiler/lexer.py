import sys
from enum import Enum, auto


_SEPARATOR_CHARS = [
    '[',
    ']',
    '(',
    ')',
    '{',
    '}',
    ';',
    '.',
    '',
    ' ',
    '\n',
]

class Lexeme(object):

    def __init__(self, typ, ln, sem=None):
        """
        ln is the source code string length of the token.
        """
        self.typ = typ
        self.ln = ln
        self.sem = sem

    def __repr__(self):
        if self.sem is None:
            return "<Lexeme typ=%s ln=%d>" % (self.typ, self.ln)
        return "<Lexeme typ=%s ln=%d sem=%s>" % (self.typ, self.ln, self.sem)

# Lexeme types

# Operators
ASSIGN = Lexeme('ASSIGN', 1)
EQUAL = Lexeme('EQUAL', 2)
ADD = Lexeme('ADD', 1)
SUB = Lexeme('SUB', 1)
MULT = Lexeme('MULT', 1)
DIV = Lexeme('DIV', 1)
MOD = Lexeme('MOD', 1)
LEQ = Lexeme('LEQ', 2)
LT = Lexeme('LT', 1)
GEQ = Lexeme('GEQ', 2)
GT = Lexeme('GT', 1)
NOT = Lexeme('NOT', 1)
AND = Lexeme('AND', 2)
OR = Lexeme('OR', 2)
E_AND = Lexeme('E_AND', 1)
E_OR = Lexeme('E_OR', 1)

# Separators
LPAREN = Lexeme('LPAREN', 1)
RPAREN = Lexeme('RPAREN', 1)
LBRACE = Lexeme('LBRACE', 1)
RBRACE = Lexeme('RBRACE', 1)
LBRACK = Lexeme('LBRACK', 1)
RBRACK = Lexeme('RBRACK', 1)

SEMICOL = Lexeme('SEMICOL', 1)
DOT = Lexeme('DOT', 1)
COMMA = Lexeme('COMMA', 1)

# Identifier
IDENT = lambda word: Lexeme('IDENT', len(word), word)

# String


def STRING(word, ln=None):
    """
    ln is defaulted to the word length. ln will be explicitly specified
    if there were escape characters as they are only one char in the
    string but two in source code.
    """
    if ln is None:
        ln = len(word)
    return Lexeme('STRING', ln, word)


def CHAR(word, ln=1):
    """
    ln is defaulted to 1. ln will be explicitly specified if there were
    escape characters as they are only one char in the string but two in
    source code.
    """
    return Lexeme('CHAR', ln, word)


# Number


def NUM(val, ln): return Lexeme('NUM', ln, val)


class Scanner(object):

    def __init__(self, s):
        self._orig_s = s
        self._s = s.strip()
        self._peek_amt = 0
        self._lexemes = []

    def lex(self):
        while len(self._s) > 0:
            self._skip_whitespace()
            try:
                lexeme = self._scan()
            except Exception as e:
                print("ERROR: lexemes=%s\n%s" % (self._lexemes, e))

            self._lexemes.append(lexeme)
            self._proceed(lexeme)

        return self._lexemes

    def _peek(self, amt=0):
        self._peek_amt = amt
        return self._s[amt]

    def _skip_whitespace(self):
        self._s = self._s.lstrip()

    def _proceed(self, lexeme):
        self._s = self._s[lexeme.ln:]

    def _get_escaped_char(self, ch):
        if ch == 'b':
            return '\b'
        elif ch == 't':
            return '\t'
        elif ch == 'n':
            return '\n'
        elif ch == 'f':
            return '\f'
        elif ch == 'r':
            return '\r'

        # TODO(joey): I am not sure if this is supposed
        # allow any other character to work. This is
        # escaping:
        #   ' " \ 0
        # We may want to whitelist only those above characters.
        return ch

    def _scan(self):
        """
        """

        # FIXME(joey): Handle EOF in cases where we continually peek
        # characters. This only applies to string and character
        # literals. Identifiers should be returned.

        # Operators
        if self._peek() == '=':
            if self._peek(1) == '=':
                # ==
                return EQUAL
            # =
            return ASSIGN
        elif self._peek() == '+':
            # +
            return ADD
        elif self._peek() == '-':
            # -
            return SUB
        elif self._peek() == '*':
            # *
            return MULT
        elif self._peek() == '/':
            # /
            return DIV
        elif self._peek() == '%':
            # %
            return MOD
        elif self._peek() == '<':
            if self._peek(1) == '=':
                # <=
                return LEQ
            # <
            return LT
        elif self._peek() == '>':
            if self._peek(1) == '=':
                # >=
                return GEQ
            # >
            return GT
        elif self._peek() == '!':
            # !
            return NOT
        elif self._peek() == '&':
            if self._peek(1) == '&':
                # &&
                return AND
            # &
            return E_AND
        elif self._peek() == '|':
            if self._peek(1) == '|':
                # ||
                return OR
            # |
            return E_OR

        # Separators
        if self._peek() == '(':
            return LPAREN
        elif self._peek() == ')':
            return RPAREN
        elif self._peek() == '[':
            return LBRACE
        elif self._peek() == ']':
            return RBRACE
        elif self._peek() == '{':
            return LBRACK
        elif self._peek() == '}':
            return RBRACK
        elif self._peek() == ';':
            return SEMICOL
        elif self._peek() == ',':
            return COMMA
        elif self._peek() == '.':
            return DOT

        # Identifiers
        if self._peek().isalpha():
            word = ""
            i = 0
            while self._peek(i).isalpha():
                word += self._peek(i)
                i += 1
            if len(word) > 0:
                return IDENT(word)

        # Parse numbers.
        if self._peek().isdigit():
            num = ""
            i = 0
            while self._peek(i).isdigit():
                num += self._peek(i)
                i += 1
            if len(num) > 0:
                try:
                    val = int(num)
                    return NUM(val, len(num))
                except:
                    pass

        # Parse string and character literals.
        if self._peek() == "\"" or self._peek() == "\'":
            quote_type = "\""
            if self._peek() == "\'":
                quote_type = "\'"

            string = ""
            # Start reading the next character.
            i = 1
            escaped_chars = 0
            while self._peek(i) != quote_type:
                ch = self._peek(i)
                # Check if the char is escaping the next char. If it is,
                # get the escaped char.
                if ch == '\\':
                    escaped_ch = self._peek(i + 1)
                    ch = self._get_escaped_char(escaped_ch)
                    escaped_chars += 1
                    # Move forward another character.
                    i += 1
                string += ch
                i += 1

            # When scanning character literals longer than 1, it is
            # invalid.
            # FIXME(joey): Handle this error better, for example exit early.
            if quote_type == "\'" and len(string) > 1:
                return Lexeme('BAD', len(string) + escaped_chars + 2, string)

            # Also count the quotation characters and escaping
            # backslashes.
            return STRING(string, len(string) + escaped_chars + 2)

        return Lexeme('BAD', 1, self._peek())


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("""Usage: pass the source code file to scan.

        For example,

                python3 {filename} main.java""".format(filename=sys.argv[0]))
        sys.exit(1)

    input_file = sys.argv[1]
    print("Reading %s" % input_file)
    lines = None
    with open(input_file, 'r') as file:
        lines = file.readlines()

    s = Scanner("\n".join(lines))

    lexemes = s.lex()
    for lexeme in lexemes:
        if lexeme.typ == 'BAD':
            print("=== BAD ===")
            print(lexemes)
            sys.exit(42)

    # print("=== DONE ===")
    # print(lexemes)
