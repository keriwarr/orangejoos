require "./lexeme"
require "./compiler_errors"
require "./util"

NEWLINES = Set{'\n', '\r'}

# The Scanner scans the input from a program and produces lexemes.
# All valid tokens are enumerated as a switch case in scan_lexeme().
# The switch case represents multiple regular languages for each type of
# token, converted to a switch case.
class Scanner
  # Scanner takes the input, an array of bytes to break it into tokens.
  def initialize(@input : Bytes)
    # Check for non 7-bit ASCII characters (outside 0 to 127).
    @input.each_with_index do |byte, idx|
      if byte > 127
        raise ScanningStageError.new("unexpected non-7bit ASCII character: #{byte} at position #{idx}", [] of Lexeme)
      end
    end

    # TODO: (joey) Might be worth looking into StringScanner for
    # cool-ness (and speed?).
    @lexemes = Array(Lexeme).new
  end

  # Generates tokens from an input string.
  #
  # Raises `ScanningStageError` if the input cannot be successfully
  # scanned.
  def scan
    self.skip_whitespace
    while @input.size > 0
      begin
        lexeme = self.scan_lexeme
      rescue ex : ScanningStageError
        raise ex # re-raise any ScanningStageError
      rescue ex : Exception
        # When other exceptions are encountered, also print out the lexemes
        STDERR.puts "lexemes=#{@lexemes}"
        raise ex
      end
      @lexemes.push(lexeme)
      self.proceed(lexeme)
      self.skip_whitespace
    end
    return @lexemes
  end

  # Skips all the of preceding whitespace in the input.
  def skip_whitespace
    while @input.size > 0 && @input.first.unsafe_chr.ascii_whitespace?
      # Move the slice by 1 chr.
      @input = @input + 1
    end
  end

  # Peeks i characters ahead in the input.
  # FIXME: (joey) Does not handle EOFs well. This may break on badly on
  # bad input, but that will end up with a ScanningStageError.
  def peek(i : Int32)
    return @input[i].unsafe_chr
  end

  # Checks if the i-th character in the input is the EOF (or past EOF).
  def eof?(i : Int32)
    return @input.size <= i
  end

  # Move forward in the input by the lexeme.
  def proceed(lexeme : Lexeme)
    # Move the slice by lexeme.size chrs.
    @input = @input + lexeme.size
  end

  # Produces a lexeme for the input.
  def scan_lexeme
    # Comments are outside of switch statement due to the conflict
    # with / (DIV). By having this greedily check for a comment
    # beforehand, we don't need to worry about embedding this logic
    # inside the operator case.
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                         SINGLE LINE COMMENTS                            #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    if self.peek(0) == '/' && self.peek(1) == '/'
      eol = 0
      # FIXME: (joey) Handle EOF.
      while !self.eof?(eol) && !NEWLINES.includes?(self.peek(eol))
        eol += 1
      end
      # Grab the comment content. It is everything after the "//".
      comment = String.new(@input[2, eol - 2])
      return Lexeme.new(Type::Comment, eol, comment)
    end

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                          MULTI-LINE COMMENTS                            #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    if self.peek(0) == '/' && self.peek(1) == '*'
      javadoc_comment = false
      end_of_comment = 1

      # If the comment is a Javadoc comment, i.e. it begins with "/**",
      # then we need to track this to determine the different comment
      # closing and to offset the end.
      if self.peek(2) == '*'
        javadoc_comment == true
        # When there is a javadoc "/**", we also shift the possible end
        # of the comment by one. This prevents re-using the second '*'
        # as an end comment.
        end_of_comment = 2
      end

      # FIXME: (joey) Handle EOF.
      while true
        if self.eof?(end_of_comment)
          raise ScanningStageError.new("unterminated multi-line comment.", @lexemes)
        end
        if self.peek(end_of_comment) == '*' && self.peek(end_of_comment + 1) == '/'
          break
        end
        end_of_comment += 1
      end

      # Grab the multi-line comment content. If it is a Javadoc comment,
      # we shift the comment contents by one. Because `end_of_comment`
      # does not include "*/", we also need to offset it for the lexeme
      # size.
      if javadoc_comment
        comment = String.new(@input[3, end_of_comment - 3])
        return Lexeme.new(Type::JavadocComment, end_of_comment + 2, comment)
      else
        comment = String.new(@input[2, end_of_comment - 2])
        return Lexeme.new(Type::MultilineComment, end_of_comment + 2, comment)
      end
    end

    case self.peek(0)
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                              OPERATORS                                  #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when '='
      case self.peek(1)
      when '=' then return Lexeme.new(Type::Operator, 2, Operator::EQ) # ==


      else return Lexeme.new(Type::Operator, 1, Operator::ASSIGN) # =


      end
    when '!'
      case self.peek(1)
      when '=' then return Lexeme.new(Type::Operator, 2, Operator::NEQ) # !=


      else return Lexeme.new(Type::Operator, 1, Operator::NOT) # !


      end
    when '+' then return Lexeme.new(Type::Operator, 1, Operator::ADD) # +


    when '-' then return Lexeme.new(Type::Operator, 1, Operator::SUB) # -


    when '*' then return Lexeme.new(Type::Operator, 1, Operator::MULT) # *


    when '/' then return Lexeme.new(Type::Operator, 1, Operator::DIV) # /


    when '%' then return Lexeme.new(Type::Operator, 1, Operator::MOD) # %


    when '<'
      case self.peek(1)
      when '=' then return Lexeme.new(Type::Operator, 2, Operator::LEQ) # <=


      else return Lexeme.new(Type::Operator, 1, Operator::LT) # <


      end
    when '>'
      case self.peek(1)
      when '=' then return Lexeme.new(Type::Operator, 2, Operator::GEQ) # >=


      else return Lexeme.new(Type::Operator, 1, Operator::GT) # >


      end
    when '&'
      case self.peek(1)
      when '&' then return Lexeme.new(Type::Operator, 2, Operator::AND) # &&


      else return Lexeme.new(Type::Operator, 1, Operator::EAND) # &


      end
    when '|'
      case self.peek(1)
      when '|' then return Lexeme.new(Type::Operator, 2, Operator::OR) # ||


      else return Lexeme.new(Type::Operator, 1, Operator::EOR) # |


      end
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
      #                             SEPERATORS                                  #
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when '(' then return Lexeme.new(Type::Separator, 1, Separator::LPAREN)
    when ')' then return Lexeme.new(Type::Separator, 1, Separator::RPAREN)
    when '[' then return Lexeme.new(Type::Separator, 1, Separator::LBRACK)
    when ']' then return Lexeme.new(Type::Separator, 1, Separator::RBRACK)
    when '{' then return Lexeme.new(Type::Separator, 1, Separator::LBRACE)
    when '}' then return Lexeme.new(Type::Separator, 1, Separator::RBRACE)
    when ';' then return Lexeme.new(Type::Separator, 1, Separator::SEMICOL)
    when ',' then return Lexeme.new(Type::Separator, 1, Separator::COMMA)
    when '.' then return Lexeme.new(Type::Separator, 1, Separator::DOT)
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
      #                        IDENTIFIERS & KEYWORDS                           #
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when .ascii_letter?, '_', '$'
      word = ""
      i = 0
      while self.peek(i).ascii_letter? || self.peek(i).ascii_number? || ['_', '$'].includes?(self.peek(i))
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

      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
      #                            NUMBER LITERAL                               #
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when .ascii_number?
      num_str = ""
      i = 0
      while self.peek(i).ascii_number?
        num_str += self.peek(i)
        i += 1
      end
      if num_str.size > 0
        # Check if the literal is an octal, and raise an error if it is.
        # Octal literals are denoted with a prefix of 0.
        if num_str.size > 1 && num_str[0] == '0'
          raise ScanningStageError.new("found octal literal, which is unsupported: #{num_str}", @lexemes)
        end

        return Lexeme.new(Type::NumberLiteral, num_str.size, num_str)
      end

      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
      #                       STRING & CHARACTER LITERAL                        #
      # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
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
          if self.eof?(i + 1)
            raise ScanningStageError.new("hit EOF while scanning string. string appears to be unterminated", @lexemes)
          end
          escaped_ch = self.peek(i + 1)
          if escaped_ch.ascii_number?
            # Read in an escaped octal value.
            num_str = "#{escaped_ch}"

            if self.eof?(i + 2)
              raise ScanningStageError.new("hit EOF while scanning string. string appears to be unterminated", @lexemes)
            end

            # Escaped octal value with 2 digits.
            escaped_ch = self.peek(i + 2)
            if escaped_ch.ascii_number? && escaped_ch.to_i < 8
              num_str += escaped_ch

              if self.eof?(i + 3)
                raise ScanningStageError.new("hit EOF while scanning string. string appears to be unterminated", @lexemes)
              end

              # Escaped octal value with 3 digits.
              escaped_ch = self.peek(i + 3)
              if escaped_ch.ascii_number? && num_str[0].to_i < 4 && escaped_ch.to_i < 8
                num_str += escaped_ch
              end
            end

            # If the octal is larger than 377 (255 in decimal) than it
            # is out of Uint8 bounds.
            if num_str.size == 3 && num_str[0] > '3'
              raise ScanningStageError.new("escaped octal out of bounds, got: #{num_str}", @lexemes)
            end
            # Parse the octal number.
            begin
              num = num_str.to_u8(8)
            rescue
              raise ScanningStageError.new("invalid escape character, expected octal got: #{num_str}", @lexemes)
            end
            escaped_chars += num_str.size
            i += num_str.size
            ch = num.unsafe_chr
          else
            ch = Util.get_escaped_char(escaped_ch)
            escaped_chars += 1
            # Move forward another character.
            i += 1
            # It is a compile error if a character escaped is
            # not a valid one.
            if ch.nil?
              raise ScanningStageError.new("invalid escape character, got: #{escaped_ch}", @lexemes)
            end
          end
        end

        str += ch
        i += 1

        # Check if the string is unterminated and we've hit the EOF.
        if self.eof?(i)
          raise ScanningStageError.new("hit EOF while scanning string. string appears to be unterminated", @lexemes)
        end
      end

      # When scanning character literals longer than 1, it is invalid.
      # FIXME: (joey) Handle this error better, for example exit early.
      if quote_typ == '\'' && str.size != 1
        return Lexeme.new(Type::Bad, str.size + escaped_chars + 2, str)
      end

      # Ensure quotation characters and escaped characters are
      # included in the lexeme size.
      if quote_typ == '\''
        return Lexeme.new(Type::CharacterLiteral, str.size + escaped_chars + 2, str)
      end
      return Lexeme.new(Type::StringLiteral, str.size + escaped_chars + 2, str)
      # No Lexeme matched
    end
    return Lexeme.new(Type::Bad, 1, self.peek(0).to_s)
  end
end
