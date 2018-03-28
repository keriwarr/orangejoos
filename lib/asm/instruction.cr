module ASM
  class Instruction
    property read_registers : Set(Register) = Set(Register).new
    property write_registers : Set(Register) = Set(Register).new

    property? destination : Register?

    @text : String

    def initialize(@text : String)
    end

    def to_s : String
      @text
    end
  end
end
