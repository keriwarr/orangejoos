# Scanner scans the input from a program and produces lexemes.
#
# All valid tokens are enumerated as a switch case in scan_lexeme().
#
class Scanner

    # Scanner takes the input, an array of bytes to break it into tokens.
    def initialize(input: Array(Char))
      @input = input
      @lexemes = Array(Lexeme)
    end

    # scan() takes the input, an array of bytes, and breaks it into tokens.
    # throws an UnscannableException if the input cannot be successfully scanned.
    # or something like that
    def scan
      while @input.length > 0
        self.skip_whitespace()
        lexeme = self.scan_lexeme()
        @lexemes.push(lexeme)
        self.proceed(lexeme)
      end
      return @lexemes
    end

    # Skips all the of preceding whitespace in the input.
    private def skip_whitespace()
      while @input.first.ascii_whitespace?
        @input.shfit
      end
    end

    private def peek(i: Num)
      return @input[i]
    end

    private def scan_lexeme()
      case self.peek()
      # === Operators ===
      when '='
        case self.peek(1)
        # ==
        when '=' then return Lexeme(Operator, 2, OpEQ)
        # =
        else return Lexeme(Operator, 1, OpASSIGN)
        end
      when '!'
        case self.peek(1)
        # !=
        when '=' then return Lexeme(Operator, 2, OpNEQ)
        # !
        else return Lexeme(Operator, 1, OpNOT)
        end
      # +
      when '+' then return Lexeme(Operator, 1, OpADD)
      # -
      when '-' then return Lexeme(Operator, 1, OpSUB)
      # *
      when '*' then return Lexeme(Operator, 1, OpMULT)
      # /
      when '/' then return Lexeme(Operator, 1, OpDIV)
      # %
      when '%' then return Lexeme(Operator, 1, OpMOD)
      when '<'
        case self.peek(1)
        # <=
        when '=' then return Lexeme(Operator, 2, OpLEQ)
        # <
        else return Lexeme(Operator, 1, OpLT)
        end
      when '>'
        case self.peek(1)
        # >=
        when '=' then return Lexeme(Operator, 2, OpGEQ)
        # >
        else return Lexeme(Operator, 1, OpGT)
        end
      when '&'
        case self.peek(1)
        # &&
        when '&' then return Lexeme(Operator, 2, OpAND)
        # &
        else return Lexeme(Operator, 1, OpEAND)
        end
      when '|'
        case self.peek(1)
        # ||
        when '|' then return Lexeme(Operator, 2, OpOR)
        # |
        else return Lexeme(Operator, 1, OpEOR)
        end
      # === Separators ===
      # (
      when '(' then return Lexeme(Separator, 1, LPAREN)
      # )
      when ')' then return Lexeme(Separator, 1, RPAREN)
      # [
      when '[' then return Lexeme(Separator, 1, LBRACE)
      # ]
      when ']' then return Lexeme(Separator, 1, RBRACE)
      # {
      when '{' then return Lexeme(Separator, 1, LBRACK)
      # }
      when '}' then return Lexeme(Separator, 1, RBRACK)
      # ;
      when ';' then return Lexeme(Separator, 1, SEMICOL)
      # ,
      when ',' then return Lexeme(Separator, 1, COMMA)
      # .
      when '.' then return Lexeme(Separator, 1, DOT)
      # === Identifiers and keywords ===
      when .ascii_letter?
        word = ""
        i = 0
        while self.peek(i).ascii_letter?
            word += self.peek(i)
            i += 1
        end
        if word.length > 0
          if BOOL_LITERALS.includes?(word) or NULL_LITERAL.includes?(word)
            # bool and null literals
            return Lexeme(Keyword, word.length, word)
          elsif KEYWORDS.includes(word)
            # keywords
            return Lexeme(Keyword, word.length, word)
          else
            # identifiers
            return IDENT(word)
          end
        end
      # === Number literal ===
      when .ascii_number?
        num_str = ""
        i = 0
        while self.peek(i).ascii_letter?
          num_str += self.peek(i)
          i += 1
        end
        if num_str.length > 0
          # FIXME(joey): Catch an error if the number is invalid or
          # causes overflow/underflow.
          return Lexeme(Number, num_str.length, num_str.to_i)
        end
      # === String and character literals ===
      when '\'', '"'
        typ = self.peek()
        str = ""
        # Start reading the next character.
        i = 1
        escaped_chars = 0
        while self.peek(1) != typ
          ch = self.peek(i)
          # Check if the char is escaping the next char. If it is, get
          # the escaped char.
          if ch == '\\'
            escaped_ch = self.peek(i + 1)
            ch = self.get_escaped_char(escaped_ch)
            escaped_chars += 1
            # Move forward another character.
            i += 1
            # It is a compile error if a character escaped is
            # not a valid one.
            if ch.nil?
              return Lexeme(Bad, str.length + escaped_chars + 2, str)
            end
            str += ch
            i += 1
          end

          # When scanning character literals longer than 1, it is
          # invalid.
          # FIXME(joey): Handle this error better, for example exit early.
          if typ == "\'" && str.length > 1
            return Lexeme(Bad, str.length + escaped_chars + 2, str)
          end

          # Ensure quotation characters and escaped characters are
          # included in the lexeme size.
          if quote_type == "\'"
            return Lexeme(CharacterLiteral, str.length + escaped_chars + 2, str)
          return Lexeme(StringLiteral, str.length + escaped_chars + 2, str)
        end
      end
      return Lexeme(Bad, 1, self.peek())
    end

    private def proceed(lexeme: Lexeme)
      @input.shift(lexeme.length)
    end

end
