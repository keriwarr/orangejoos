require "asm/file_dsl"
require "asm/register"
require "asm/instructions"

class CodeGenerator
  property vtable : VTable
  property verbose : Bool
  property output_dir : String

  def initialize(@vtable : VTable, @verbose : Bool, @output_dir : String)
  end

  def generate(file : SourceFile)
    file.ast.accept(CodeGenerationVisitor.new(output_dir, file))
  end

  def generate_entry(files : Array(SourceFile))
    entry_fcn = find_entry_fcn(files)
    entry_label = entry_fcn.label.to_s
    entry_path = File.join(output_dir, "__entry.s")
    f = File.open(entry_path, "w")
    f << "" \
"; === Joos1W program entry

  SECTION .text
  GLOBAL start ; MacOS (macho) entry point
  GLOBAL _start ; Linux (elf_i386) entry point
  EXTERN #{entry_label}
start:
_start:
  CALL #{entry_label}
  ; Call exit. The status code is returned into EAX, which exit() uses.
  CALL _exit

; exit(status : Int)
; status is in EAX
_exit:
  ; Call the syscall sys_exit(status).
%ifidn __OUTPUT_FORMAT__, macho
  ; The BSD semantics for syscalls is that arguments are pushed to the stack.
  PUSH EAX ; push the exit static code for the syscall arg.
  MOV EAX, 1 ; denotes syscall 1, sys_exit(status).
  PUSH EAX ; ??? not sure what this is for and why. it is part of how systcall work.
  INT 0x80 ; enter the syscall interrupt.
%elifidn __OUTPUT_FORMAT__, elf
  ; exit code. Linux semantics is arguments are put into registers on syscalls.
  MOV EBX, EAX ; Move the argument (status) to EBX
  MOV EAX, 1 ; syscall 1, exit(status)
  INT 0x80 ; enter the syscall interrupt
%else
  %error unimplemented for output format __OUTPUT_FORMAT__
%endif
"
    f.close()
  end

  def find_entry_fcn(files : Array(SourceFile)) : AST::MethodDecl
    # Honestly, I think this may be cleaner as a short visitor that
    # raises once it finds the `static int test()` method.
    files.each do |file|
      file.ast.decls.each do |typ_decl|
        if typ_decl.is_a?(AST::ClassDecl)
          typ_decl.body.each do |member|
            if member.is_a?(AST::MethodDecl)
              if member.name == "test" &&
                 member.typ? && member.typ.to_type.typ == Typing::Types::INT &&
                 member.has_mod?("static") && member.has_mod?("public")
                return member
              end
            end
          end
        end
      end
    end
    raise CodegenError.new("could not find static int test() entry point")
  end
end

class CodeFile
  include ASM::FileDSL

  property path : String
  property source_path : String
  property typ_decl : AST::TypeDecl

  def initialize(@path : String, @source_path : String, @typ_decl : AST::TypeDecl)
    @f = String::Builder.new
    f << "; === orangejoos generated Joos1W x86-32\n"
    f << "; === interface: #{typ_decl.package}.#{typ_decl.name}\n" if typ_decl.is_a?(AST::InterfaceDecl)
    f << "; === class: #{typ_decl.package}.#{typ_decl.name}\n" if typ_decl.is_a?(AST::ClassDecl)
    # FIXME(joey): This path is often munged, e.g. multiple //.
    f << "; === source: #{source_path}\n"
    f << "  SECTION .text\n\n\n"
    # TODO(joey): Add comments indicating the object layout.
  end

  def <<(s : String) : CodeFile
    f << " " * self.indentation << s
    return self
  end

  def write_and_close
    # This seems like the most efficient way to handle this, as all IO
    # will be in memory and then each file dumps sequentially. This also
    # means, as we handle one file at a time, we will not run against
    # memory limits.
    file = File.open(path, "w")
    file << @f.to_s
    file.close()
  end
end

# `CodeCreationVisitor`
# FIXME(joey): CodeGenerationVisitor can only handle files with a single
# entity. We will need to change this DSL/generator to handle otherwise.
class CodeGenerationVisitor < Visitor::GenericVisitor
  include ASM::FileDSL

  property output_dir : String
  property file : SourceFile

  def initialize(@output_dir : String, @file : SourceFile)
  end

  def visit(node : AST::ClassDecl) : Nil
    source_path = @file.path

    annotate "orangejoos generated Joos1W x86-32"
    annotate "interface: #{node.package}.#{node.name}" if node.is_a?(AST::InterfaceDecl)
    annotate "class: #{node.package}.#{node.name}" if node.is_a?(AST::ClassDecl)
    # FIXME(joey): This path is often munged, e.g. multiple //.
    annotate "source: #{source_path}"
    raw "  SECTION .text\n"

    super

    file_name = node.qualified_name.split(".").join("_") + ".s"
    path = File.join(output_dir, file_name)
    write_to_file(path)
  rescue ex : CompilerError
    ex.register("class_name", node.name)
    raise ex
  end

  def visit(node : AST::MethodDecl) : Nil
    unless node.has_mod?("static")
      STDERR.puts "unimplemented: non-static methods. not compiling #{node.parent.qualified_name} {#{node.name}}"
      return
    end

    comment "static method #{node.parent.name}.#{node.name}"
    method(node.label) do
      super
    end
  rescue ex : CompilerError
    ex.register("method_name", node.name)
    raise ex
  end

  def visit(node : AST::ReturnStmt) : Nil
    super
    stack_size = 0
    instr ASM.ret stack_size
  end

  def visit(node : AST::ExprOp) : Nil
    op_types = node.operands.map &.get_type
    if ["+", "-", "/", "*", "%"].includes?(node.op) && op_types.all? &.is_number?
      # Add code for LHS.
      node.operands[0].accept(self)
      # Push the LHS result (EAX) to the stack.
      instr ASM.push ASM::Register::EAX
      # Add code for RHS.
      node.operands[1].accept(self)
      # Compute LHS + RHS into EAX
      instr ASM.pop ASM::Register::EBX
      # Do operations.
      # FIXME(joey): It would probably be better to not just be writing
      # strings to a file/stringbuilder. Using the ENUMS and all
      # available in lib/asm would be great for compile-time
      # correctness.
      case node.op
      when "+" then instr ASM.add ASM::Register::EAX, ASM::Register::EBX
      when "-" then instr ASM.sub ASM::Register::EAX, ASM::Register::EBX
      when "*" then instr ASM.imult ASM::Register::EAX, ASM::Register::EBX
      # IDIV: divide EAX by the parameter and put the quotient in EAX
      # and remainder in EDX.
      when "/" then instr ASM.idiv ASM::Register::EBX
      when "%"
        instr ASM.idiv ASM::Register::EBX
        instr ASM.mov ASM::Register::EAX, ASM::Register::EDX
      end
      return
    end

    if ["=="].includes?(node.op) && op_types.all? &.is_number?
      # Add code for LHS.
      node.operands[0].accept(self)
      # Push the LHS result (EAX) to the stack.
      instr ASM.push ASM::Register::EAX
      # Add code for RHS.
      node.operands[1].accept(self)
      # Compute LHS + RHS into EAX
      instr ASM.pop ASM::Register::EBX
      # FIXME(joey): TODO
      instr ASM.cmp ASM::Register::EAX, ASM::Register::EBX
      instr ASM.setc ASM::Register::EAX
    end

    raise Exception.new("unimplemented: op=#{node.op} types=#{op_types.map &.to_s}")
  end

  def visit(node : AST::ConstInteger) : Nil
    instr ASM.mov ASM::Register::EAX, node.val
  end

end