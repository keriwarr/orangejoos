class CodeGenerator
  property vtable : VTable
  property verbose : Bool
  property output_dir : String

  def initialize(@vtable : VTable, @verbose : Bool, @output_dir : String)
  end

  def generate(file : SourceFile)
    file.ast.accept(CodeGenerationVisitor.new(output_dir, file))
    file.code.output_to_file
  end

  def generate_entry(files : Array(SourceFile))
    entry_fcn = find_entry_fcn(files)
    STDERR.puts "found entry: #{entry_fcn.to_s} label: #{entry_fcn.label.to_s}"

    entry_path = File.join(output_dir, "__entry.s")
    f = File.open(entry_path, "w")
    f << "" \
"; === Joos1W entry point
global start

; Joos1W program entry.
start:
  ; Stub, exit with status 137.
  MOV EAX, 137
  CALL exit

; exit(status : Int)
; status is in EAX
exit:
  ; Call the syscall sys_exit(status).
%ifidn __OUTPUT_FORMAT__, macho
  ; The BSD semantics for syscalls is that arguments are pushed to the stack.
  PUSH EAX ; push the exit static code for the syscall arg.
  MOV EAX, 1 ; denotes syscall 1, sys_exit(status).
  PUSH EAX ; ??? not sure what this is for and why. it is part of how systcall work.
  INT 0x80 ; enter the syscall interrupt.
%elifidn __OUTPUT_FORMAT__, elf32
  [ERROR not implemented]
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
  property path : String
  property source_path : String
  property typ_decl : AST::TypeDecl

  def initialize(@path : String, @source_path : String, @typ_decl : AST::TypeDecl)
  end

  def output_to_file
    f = File.open(path, "w")
    f << "; === orangejoos generated Joos1W x86-32\n"
    f << "; === interface: #{typ_decl.package}.#{typ_decl.name}\n" if typ_decl.is_a?(AST::InterfaceDecl)
    f << "; === class: #{typ_decl.package}.#{typ_decl.name}\n" if typ_decl.is_a?(AST::ClassDecl)
    f << "; === source: #{source_path}\n"
    f.close()
  end
end

# `CodeCreationVisitor`
class CodeGenerationVisitor < Visitor::GenericVisitor
  property output_dir : String
  property file : SourceFile

  def initialize(@output_dir : String, @file : SourceFile)
  end

  def visit(node : AST::ClassDecl)
    file_name = node.qualified_name.split(".").join("_") + ".s"
    file_path = File.join(output_dir, file_name)
    # TODO(joey): Because each file only contains one class/interface,
    # this is fine. If we want to extend the compiler though, we will
    # need to create a flatmap of code files.
    file.code = CodeFile.new(file_path, @file.path, node)
    super
  rescue ex : CompilerError
    ex.register("class_name", node.name)
    raise ex
  end
end
