module ASM
  class Instruction
    ARGS_INDENT_WIDTH = 8

    property read_registers : Set(Register) = Set(Register).new
    property write_registers : Set(Register) = Set(Register).new

    property? destination : Register?

    @command : String
    @args : String

    def initialize(@command : String, @args : String)
    end

    def to_s : String
      s = @command
      if s.size < ARGS_INDENT_WIDTH
        s += " " * (ARGS_INDENT_WIDTH - s.size)
      else
        s += " "
      end
      s += @args

      s
    end
  end
end
