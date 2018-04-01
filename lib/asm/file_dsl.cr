require "asm/instruction"

module ASM
  module FileDSL
    COMMENT_START_COLUMN = 30

    @buf : String::Builder = String::Builder.new
    @next_comment : String = ""
    @annotating : Bool = true
    @indentation : Int32 = 0

    def write_to_file(path : String)
      file = File.open(path, "w")
      file << @buf.to_s
      file.close
    end

    def annotate(s : String) : Nil
      raise Exception.new("cannot append to header after writing data") if !@annotating
      @buf << "; === " << s << "\n"
    end

    def end_annotation : Nil
      @annotating = false
      @buf << "\n"
    end

    def raw(s : String) : Nil
      end_annotation if @annotating
      @buf << s
    end

    def print_line(s : String) : Nil
      end_annotation if @annotating
      line_length = 2 * @indentation
      @buf << "  " * @indentation
      line_length += s.size
      @buf << s
      if @next_comment.size > 0
        if line_length < COMMENT_START_COLUMN
          @buf << " " * (COMMENT_START_COLUMN - line_length)
        else
          @buf << " "
        end
        @buf << "; " << @next_comment
        @next_comment = ""
      end
      @buf << "\n"
    end

    def instr(inst : Instruction) : Nil
      print_line inst.to_s
    end

    def label(lbl : Label) : Nil
      print_line lbl.to_s + ":"
    end

    def indent(&block) : Nil
      @indentation += 1
      yield
      @indentation -= 1
    end

    def comment(s : String) : Nil
      end_annotation if @annotating
      @buf << "  " * @indentation
      @buf << "; " << s << "\n"
    end

    def comment_next_line(s : String) : Nil
      @next_comment += s
    end

    def global(lbl : Label) : Nil
      print_line "GLOBAL  #{lbl.to_s}"
    end

    def extern(lbl : Label) : Nil
      print_line "EXTERN  #{lbl.to_s}"
    end

    def section(s : String) : Nil
      print_line "SECTION .#{s}"
    end

    def section_text : Nil
      section "text"
    end

    def section_bss : Nil
      section "bss"
    end

    def section_data : Nil
      section "data"
    end

    def newline : Nil
      @buf << "\n"
    end

    def method(lbl : Label, &block) : Nil
      global lbl
      label lbl
      @indentation += 1
      yield
      @indentation -= 1
      @buf << "\n"
    end

    # Instructions.

    def asm_basic_math(op : String, r1 : Register, r2 : Register) : Nil
      i = Instruction.new("#{op}", "#{r1}, #{r2}")
      i.write_registers.add(r1)
      i.read_registers.add(r1).add(r2)
      i.destination = r1
      self.instr i
    end

    def asm_basic_math(op : String, r1 : Register, imm : Int32) : Nil
      i = Instruction.new("#{op}", "#{r1}, #{imm.to_s}")
      i.write_registers.add(r1)
      i.read_registers.add(r1)
      i.destination = r1
      self.instr i
    end

    def asm_add(r1 : Register, r2 : Register | Int32) : Nil
      asm_basic_math("ADD", r1, r2)
    end

    def asm_sub(r1 : Register, r2 : Register | Int32) : Nil
      asm_basic_math("SUB", r1, r2)
    end

    def asm_imul(r1 : Register, r2 : Register) : Nil
      asm_basic_math("IMUL", r1, r2)
    end

    def asm_idiv(divisor : Register) : Nil
      i = Instruction.new("IDIV", "#{divisor}")
      i.write_registers.add(Register::EAX).add(Register::EDX)
      i.read_registers.add(Register::EAX).add(divisor)
      # NOTE: more than one destination, so no destination is set.
      # anyways, the destination is not modifiable.
      self.instr i
    end

    def asm_cmp(r1 : Register, r2 : Register) : Nil
      i = Instruction.new("CMP", "#{r1}, #{r2}")
      i.write_registers.add(Register::FLAGS)
      i.read_registers.add(r1).add(r2)
      self.instr i
    end

    def asm_cmp(r1 : Register, imm : Int32) : Nil
      i = Instruction.new("CMP", "#{r1}, #{imm.to_s}")
      i.write_registers.add(Register::FLAGS)
      i.read_registers.add(r1)
      self.instr i
    end

    def asm_jne(lbl : Label) : Nil
      i = Instruction.new("JNE", "#{lbl.to_s}")
      # TODO: (joey) we may want to denote a control-flow jump
      self.instr i
    end

    def asm_setc(dest : Register) : Nil
      i = Instruction.new("SETC", "#{dest}")
      i.write_registers.add(dest)
      i.read_registers.add(Register::FLAGS)
      i.destination = dest
      self.instr i
    end

    def asm_mov(dest : Register | Address, src : Register | Address | Int32) : Nil
      i = Instruction.new("MOV", "#{dest.to_s}, #{src.to_s}")
      i.read_registers.add(src) if src.is_a?(Register)
      i.read_registers.add(src.register) if src.is_a?(Address)
      i.read_registers.add(dest.register) if dest.is_a?(Address)

      # No detination or write registers if we are writing to memory.
      i.write_registers.add(dest) if dest.is_a?(Register)
      i.destination = dest if dest.is_a?(Register)
      self.instr i
    end

    def asm_push(src : Register) : Nil
      i = Instruction.new("PUSH", "#{src}")
      i.read_registers.add(src)
      self.instr i
    end

    def asm_push(src : Int32) : Nil
      i = Instruction.new("PUSH", "#{src.to_s}")
      self.instr i
    end

    def asm_pop(dest : Register) : Nil
      i = Instruction.new("POP", "#{dest}")
      i.write_registers.add(dest)
      i.destination = dest
      self.instr i
    end

    def asm_ret(bytes : Int32) : Nil
      i = Instruction.new("RET", "#{bytes}")
      self.instr i
    end

    def asm_call(lbl : Label) : Nil
      i = Instruction.new("CALL", "#{lbl.to_s}")
      self.instr i
    end

    def asm_int(id : Int) : Nil
      i = Instruction.new("INT", "0x" + id.to_s(16, true))
      self.instr i
    end

    def asm_pushad : Nil
      i = Instruction.new("PUSHAD")
      self.instr i
    end

    def asm_popad : Nil
      i = Instruction.new("POPAD")
      self.instr i
    end
  end
end
