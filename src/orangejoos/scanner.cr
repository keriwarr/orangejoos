require "./lexeme.cr"

class ScanningError < Exception
end

# Scanner scans the input from a program and produces lexemes.
#
# All valid tokens are enumerated as a switch case in scan_lexeme().
#
class Scanner
  # Scanner takes the input, an array of bytes to break it into tokens.
  def initialize(input : Array(Char))
    # TODO(joey): Might be worth looking into StringScanner for
    # cool-ness (and speed?).
    @input = input
    @lexemes = Array(Lexeme).new
  end

  # scan() takes the input, an array of bytes, and breaks it into tokens.
  # throws an UnscannableException if the input cannot be successfully scanned.
  # or something like that
  def scan
    self.skip_whitespace
    while @input.size > 0
      begin
        lexeme = self.scan_lexeme
      rescue
        raise ScanningError.new(@lexemes.to_s)
      end
      @lexemes.push(lexeme)
      self.proceed(lexeme)
      self.skip_whitespace
    end
    return @lexemes
  end

  # Skips all the of preceding whitespace in the input.
  def skip_whitespace
    while @input.size > 0 && @input.first.ascii_whitespace?
      @input = @input[1, @input.size]
    end
  end

  def peek(i : Number)
    return @input[i]
  end

  def get_escaped_char(ch : Char)
    case ch
    # backspace BS
    when 'b' then return '\b'
      # horizontal tab HT
    when 't' then return '\t'
      # linefeed LF
    when 'n' then return '\n'
      # form feed FF
    when 'f' then return '\f'
      # carriage return CR
    when 'r'            then return '\r'
    when '\\'           then return '\\'
    when '"'            then return '"'
    when '\''           then return '\''
    when .ascii_number? then return ch.to_i.chr
    else                     return nil
    end
  end

  def scan_lexeme
    case self.peek(0)
    # === Operators ===
    when '='
      case self.peek(1)
      # ==
      when '=' then return Lexeme.new(Type::Operator, 2, OpEQ)
        # =
      else return Lexeme.new(Type::Operator, 1, OpASSIGN)
      end
    when '!'
      case self.peek(1)
      # !=
      when '=' then return Lexeme.new(Type::Operator, 2, OpNEQ)
        # !
      else return Lexeme.new(Type::Operator, 1, OpNOT)
      end
      # +
    when '+' then return Lexeme.new(Type::Operator, 1, OpADD)
      # -
    when '-' then return Lexeme.new(Type::Operator, 1, OpSUB)
      # *
    when '*' then return Lexeme.new(Type::Operator, 1, OpMULT)
      # /
    when '/' then return Lexeme.new(Type::Operator, 1, OpDIV)
      # %
    when '%' then return Lexeme.new(Type::Operator, 1, OpMOD)
    when '<'
      case self.peek(1)
      # <=
      when '=' then return Lexeme.new(Type::Operator, 2, OpLEQ)
        # <
      else return Lexeme.new(Type::Operator, 1, OpLT)
      end
    when '>'
      case self.peek(1)
      # >=
      when '=' then return Lexeme.new(Type::Operator, 2, OpGEQ)
        # >
      else return Lexeme.new(Type::Operator, 1, OpGT)
      end
    when '&'
      case self.peek(1)
      # &&
      when '&' then return Lexeme.new(Type::Operator, 2, OpAND)
        # &
      else return Lexeme.new(Type::Operator, 1, OpEAND)
      end
    when '|'
      case self.peek(1)
      # ||
      when '|' then return Lexeme.new(Type::Operator, 2, OpOR)
        # |
      else return Lexeme.new(Type::Operator, 1, OpEOR)
      end
      # === Separators ===
      # (
    when '(' then return Lexeme.new(Type::Separator, 1, LPAREN)
      # )
    when ')' then return Lexeme.new(Type::Separator, 1, RPAREN)
      # [
    when '[' then return Lexeme.new(Type::Separator, 1, LBRACK)
      # ]
    when ']' then return Lexeme.new(Type::Separator, 1, RBRACK)
      # {
    when '{' then return Lexeme.new(Type::Separator, 1, LBRACE)
      # }
    when '}' then return Lexeme.new(Type::Separator, 1, RBRACE)
      # ;
    when ';' then return Lexeme.new(Type::Separator, 1, SEMICOL)
      # ,
    when ',' then return Lexeme.new(Type::Separator, 1, COMMA)
      # .
    when '.' then return Lexeme.new(Type::Separator, 1, DOT)
      # === Identifiers and keywords ===
    when .ascii_letter?
      word = ""
      i = 0
      while self.peek(i).ascii_letter?
        word += self.peek(i)
        i += 1
      end
      if word.size > 0
        if BOOL_LITERALS.includes?(word) || NULL_LITERALS.includes?(word)
          # bool and null literals
          return Lexeme.new(Type::Keyword, word.size, word)
        elsif KEYWORDS.includes?(word)
          # keywords
          return Lexeme.new(Type::Keyword, word.size, word)
        else
          # identifiers
          return Lexeme.new(Type::Identifier, word.size, word)
        end
      end
      # === Number literal ===
    when .ascii_number?
      num_str = ""
      i = 0
      while self.peek(i).ascii_number?
        num_str += self.peek(i)
        i += 1
      end
      if num_str.size > 0
        # FIXME(joey): Catch an error if the number is invalid or
        # causes overflow/underflow.
        # TODO(joey): We can throw an error if the number is out of
        # bounds here. We also need to be aware of the Crystal int size.
        return Lexeme.new(Type::NumberLiteral, num_str.size, num_str)
      end
      # === String and character literals ===
    when '\'', '"'
      quote_typ = self.peek(0)
      str = ""
      # Start reading the next character.
      i = 1
      escaped_chars = 0
      while self.peek(i) != quote_typ
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
            return Lexeme.new(Type::Bad, str.size + escaped_chars + 2, str)
          end
        end
        str += ch
        i += 1
      end

      # When scanning character literals longer than 1, it is
      # invalid.
      # FIXME(joey): Handle this error better, for example exit early.
      if quote_typ == '\'' && str.size != 1
        return Lexeme.new(Type::Bad, str.size + escaped_chars + 2, str)
      end

      # Ensure quotation characters and escaped characters are
      # included in the lexeme size.
      if quote_typ == '\''
        return Lexeme.new(Type::CharacterLiteral, str.size + escaped_chars + 2, str)
      end
      return Lexeme.new(Type::StringLiteral, str.size + escaped_chars + 2, str)
      # === No lexeme matched ===
    end
    return Lexeme.new(Type::Bad, 1, self.peek(0).to_s)
  end

  def proceed(lexeme : Lexeme)
    # Remove the first lexeme.length items.
    @input = @input[lexeme.size, @input.size]
  end
end
