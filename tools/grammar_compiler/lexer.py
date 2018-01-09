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
            lexeme = self._scan()
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

    def _scan(self):
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
        elif self._peek() == '|':
            if self._peek(1) == '|':
                # ||
                return OR

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
        if s._peek().isalpha():
            word = ""
            i = 0
            while s._peek(i).isalpha():
                word += s._peek(i)
                i += 1
            if len(word) > 0:
                return IDENT(word)

        if s._peek().isdigit():
            num = ""
            i = 0
            while s._peek(i).isdigit():
                num += s._peek(i)
                i += 1
            if len(num) > 0:
                try:
                    val = int(num)
                    return NUM(val, len(num))
                except:
                    pass

        return Lexeme('BAD', 1, s._peek())


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("""Usage: pass the source code file to scan.

        For example,

                python3 {filename} main.java""".format(filename=sys.argv[0]))
        sys.exit(1)

    input_file = sys.argv[1]

    lines = None
    with open(input_file, 'r') as file:
        lines = file.readlines()

    s = Scanner("\n".join(lines))

    lexemes = s.lex()
    for lexeme in lexemes:
        if lexeme.typ == 'BAD':
            sys.exit(42)

    print("=== DONE ===")
    print(lexemes)
