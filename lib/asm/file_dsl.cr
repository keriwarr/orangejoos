
module ASM
  module FileDSL
    @@buf : String::Builder = String::Builder.new
    @@annotating : Bool = true
    @@indentation : Int32 = 0

    def write_to_file(path : String)
      file = File.open(path, "w")
      file << @@buf.to_s
      file.close()
    end

    def annotate(s : String) : Nil
      raise Exception.new("cannot append to header after writing data") if !@@annotating
      @@buf << "; === " << s << "\n"
    end

    def end_annotation : Nil
      @@annotating = false
      @@buf << "\n"
    end

    def raw(s : String) : Nil
      end_annotation if @@annotating
      @@buf << s
    end

    def instr(inst : ASM::Instruction) : Nil
      end_annotation if @@annotating
      @@buf << "  " * @@indentation
      @@buf << inst.to_s << "\n"
    end

    def comment(s : String) : Nil
      end_annotation if @@annotating
      @@buf << "  " * @@indentation
      @@buf << "; " << s << "\n"
    end

    def method(label : Label, &block) : Nil
      @@buf << "  GLOBAL #{label.to_s}\n"
      @@buf << label.to_s << ":\n"
      @@indentation += 1
      yield
      @@indentation -= 1
      @@buf << "\n"
    end
  end
end
