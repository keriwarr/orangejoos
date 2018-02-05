class Util
  # Gets the escaped character code point represented by a character.
  def self.get_escaped_char(ch : Char)
    case ch
    # backspace BS.
    when 'b' then return '\b'
      # horizontal tab HT.
    when 't' then return '\t'
      # linefeed LF.
    when 'n' then return '\n'
      # form feed FF.
    when 'f' then return '\f'
      # carriage return CR.
    when 'r' then return '\r'
      # escaped slash.
    when '\\' then return '\\'
      # escaped quote.
    when '"' then return '"'
      # escaped single quote.
    when '\'' then return '\''
      # escaped 0-9 code points.
    when .ascii_number? then return ch.to_i.chr
      # nil represents a failure.
    else return nil
    end
  end
end