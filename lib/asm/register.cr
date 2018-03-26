module ASM
  class Address
    property register : Register
    property! offset : Int32

    def initialize(@register : Register)
    end

    def initialize(@register : Register, @offset : Int32)
    end

    def to_s : String
      if !offset?
        "[#{register}]"
      elsif offset >= 0
        "[#{register}+#{offset}]"
      else
        "[#{register}-#{-offset}]"
      end
    end
  end

  # Based off https://wiki.skullsecurity.org/index.php?title=Registers
  enum Register
    EAX, AX, AH, AL,
    EBX, BX, BH, BL,
    ECX, CX, CH, CL,
    EDX, DX, DH, DL,
    ESI, SI,
    EDI, DI,
    EBP, BP,
    ESP, SP,
    EIP

    # Special register.
    FLAGS

    def as_address : ASM::Address
      return ASM::Address.new(self)
    end

    def as_address_offset(offset : Int32) : ASM::Address
      return ASM::Address.new(self, offset)
    end
  end
end
