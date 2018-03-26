require "asm/instruction"

module ASM

  def self.basic_math(op : String, r1 : Register, r2 : Register) : Instruction
    i = Instruction.new("#{op} #{r1}, #{r2}")
    i.write_registers.add(r1)
    i.read_registers.add(r1).add(r2)
    i.destination = r1
    return i
  end

  def self.add(r1 : Register, r2 : Register) : Instruction
    self.basic_math("ADD", r1, r2)
  end

  def self.sub(r1 : Register, r2 : Register) : Instruction
    self.basic_math("SUB", r1, r2)
  end

  def self.imult(r1 : Register, r2 : Register) : Instruction
    self.basic_math("IMULT", r1, r2)
  end

  def self.idiv(divisor : Register) : Instruction
    i = Instruction.new("IDIV #{divisor}")
    i.write_registers.add(Register::EAX).add(Register::EDX)
    i.read_registers.add(Register::EAX).add(divisor)
    # NOTE: more than one destination, so no destination is set.
    # anyways, the destination is not modifiable.
    # i.destination = r1
    return i
  end

  def self.cmp(r1 : Register, r2 : Register) : Instruction
    i = Instruction.new("CMP #{r1}, #{r2}")
    i.write_registers.add(Register::FLAGS)
    i.read_registers.add(r1).add(r2)
    # i.destination = dest
    return i
  end

  def self.setc(dest : Register) : Instruction
    i = Instruction.new("SETC #{dest}")
    i.write_registers.add(dest)
    i.read_registers.add(Register::FLAGS)
    i.destination = dest
    return i
  end

  def self.mov(dest : Register, src : Register) : Instruction
    i = Instruction.new("MOV #{dest}, #{src}")
    i.write_registers.add(dest)
    i.read_registers.add(src)
    i.destination = dest
    return i
  end

  # FIXME(joey): Should the String instead be an Int32?
  def self.mov(dest : Register, src : String) : Instruction
    i = Instruction.new("MOV #{dest}, #{src}")
    i.write_registers.add(dest)
    i.destination = dest
    return i
  end

  def self.push(src : Register) : Instruction
    i = Instruction.new("PUSH #{src}")
    i.read_registers.add(src)
    return i
  end

  def self.pop(dest : Register) : Instruction
    i = Instruction.new("POP #{dest}")
    i.write_registers.add(dest)
    i.destination = dest
    return i
  end

  def self.ret(bytes : Int32) : Instruction
    i = Instruction.new("RET #{bytes}")
    return i
  end
end
