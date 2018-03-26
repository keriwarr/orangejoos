require "asm/file_dsl"
require "asm/register"

include ASM

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
                 member.is_static? && member.is_public?
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

# Collects all variables for determining the stack layout.
class LocalVariableCollector < Visitor::GenericVisitor
  def initialize(@variables : Array(NamedTuple(name: String, typ: Typing::Type)))
  end

  def visit(node : AST::VarDeclStmt) : Nil
    @variables.push(NamedTuple.new(name: node.var.name, typ: node.typ.to_type))
  end
end

# `CodeCreationVisitor`
# FIXME(joey): CodeGenerationVisitor can only handle files with a single
# entity. We will need to change this DSL/generator to handle otherwise.
class CodeGenerationVisitor < Visitor::GenericVisitor
  include ASM::FileDSL

  property output_dir : String
  property file : SourceFile

  property! stack_size : Int32

  property if_counter : Int32 = 0

  property printed = false

  def initialize(@output_dir : String, @file : SourceFile)
  end

  def visit(node : AST::ClassDecl) : Nil
    source_path = @file.path
    # Skip all stdlib files for now.
    return if node.package.includes?("java")

    annotate "orangejoos generated Joos1W x86-32"
    annotate "interface: #{node.package}.#{node.name}" if node.is_a?(AST::InterfaceDecl)
    annotate "class: #{node.package}.#{node.name}" if node.is_a?(AST::ClassDecl)
    # FIXME(joey): This path is often munged, e.g. multiple //.
    annotate "source: #{source_path}"
    raw "  SECTION .text\n\n\n"

    super

    file_name = node.qualified_name.split(".").join("_") + ".s"
    path = File.join(output_dir, file_name)
    write_to_file(path)
  rescue ex : CompilerError
    ex.register("class_name", node.name)
    raise ex
  end

  def visit(node : AST::MethodDecl) : Nil
    unless node.is_static?
      STDERR.puts "unimplemented: non-static methods. not compiling #{node.parent.qualified_name} {#{node.name}}"
      return
    end

    # Collect all stack variables.
    variables = [] of NamedTuple(name: String, typ: Typing::Type)
    node.accept(LocalVariableCollector.new(variables))
    # Pretend everything takes up 32bits, lazy because our test is
    # J1_random_arithmetic.
    self.stack_size = variables.sum {|i| 4 }

    comment "static method #{node.parent.name}.#{node.name}"
    method(node.label) do
      comment "save old base pointer"
      asm_push Register::EBP
      comment "set the new base pointer value"
      asm_mov Register::EBP, Register::ESP

      # Initialize the stack frame of the method. This involves:
      # 1) Shifting ESP by the stack size.
      # 2) Initializing the stack data.
      variables.each do |var|
        # FIXME: (joey) for now, we push zeros for everything. To support
        # non-word sized types, we should be smarter about it.
        comment "init space for localvar {#{var[:name]}}"
        asm_push 0
      end
      super
    end
  rescue ex : CompilerError
    ex.register("method_name", node.name)
    raise ex
  end

  def visit(node : AST::ReturnStmt) : Nil
    # Calculate the return expression. It will end up in EAX, our
    # convention for returning values.
    super
    # We return with the stack_size as it discards items on the stack
    # that have not yet been popped, i.e. localvars, so that the top
    # item on the stack is EIP for returning.
    # TODO: (joey) we can add one "method$...$ret" label at the end of
    # the method where we only need to have the common end instructions
    # once.
    # TODO: (joey) if we change calling convention so caller saves and
    # restores EBP, then we should instead use "RET n" to de-allocate
    # the stack in one instruction.
    comment "de-allocate local variables by recovering callers ESP"
    asm_mov Register::ESP, Register::EBP
    comment "restore callers base pointer"
    asm_pop Register::EBP
    asm_ret 0
  end

  def visit(node : AST::IfStmt) : Nil
    # if-label
    if_label = ASM::Label.new("if_#{if_counter}")
    # if-cond-label
    if_cond_label = ASM::Label.new("if_cond_#{if_counter}")
    # else-label
    if_else_label = ASM::Label.new("if_else_#{if_counter}")
    # if-end-label
    if_end_label = ASM::Label.new("if_end_#{if_counter}")
    self.if_counter += 1

    comment "if-stmt with original expr=#{node.expr.original.to_s}"

    expr = node.expr
    if expr.is_a?(AST::ConstBool)
      if expr.val == true
        comment "elided if-stmt with expr=bool(true)"
        node.if_body.accept(self)
        return
      else
        if node.else_body?
          comment "elided if-stmt with expr=bool(false)"
          node.else_body.accept(self)
        else
          comment "elided if-stmt with expr=bool(false) and no else body"
        end
        return
      end
    end

    # Write code for evaluting if-stmt.
    label if_cond_label
    node.expr.accept(self)
    asm_cmp Register::EAX, 1

    if node.else_body?
      asm_jne if_else_label
    else
      asm_jne if_end_label
    end

    label if_label
    indent do
      node.if_body.accept(self)
    end

    if node.else_body?
      label if_else_label
      indent do
        node.else_body.accept(self)
      end
    end

    label if_end_label
  end


  def visit(node : AST::ExprOp) : Nil
    op_types = node.operands.map &.get_type
    op_sig = {node.op, node.operands[0].get_type, node.operands[1].get_type}

    # FIXME: (joey) when the LHS is for an address, we need to do
    # something specific to either keep it as an address or get the
    # value. Hence the separation between assignment and the rest.
    if op_sig[0] == "=" && op_sig[1].is_number? && op_sig[2].is_number?
      # Add code for LHS.
      calculate_address(node.operands[0])
      # Push the LHS address (EAX) to the stack.
      asm_push Register::EAX
      # Compute RHS.
      node.operands[1].accept(self)
      # Get LHS address.
      asm_pop Register::EBX
      # Put result into address.
      # TODO: (joey) in the case of a Param or VarDeclStmt, we can elide
      # the address computation and embed the offset directly here.
      asm_mov Register::EBX.as_address, Register::EAX
      # NOTE: the result is in EAX, as desired as '=' is an expression.
    elsif node.operands.size == 2
      # Add code for LHS.
      node.operands[0].accept(self)
      # Push the LHS result (EAX) to the stack.
      # TODO: (joey) if the operand is a constant, we can alide the load
      # and embed it into the push.
      asm_push Register::EAX
      # Add code for RHS.
      node.operands[1].accept(self)
      # Compute LHS + RHS into EAX
      asm_pop Register::EBX

      # Do operations.
      case {node.op, node.operands[0].get_type, node.operands[1].get_type}
      when {"+", .is_number?, .is_number?} then asm_add Register::EAX, Register::EBX
      when {"-", .is_number?, .is_number?} then asm_sub Register::EAX, Register::EBX
      when {"*", .is_number?, .is_number?} then asm_imult Register::EAX, Register::EBX
      # IDIV: divide EAX by the parameter and put the quotient in EAX
      # and remainder in EDX.
      when {"/", .is_number?, .is_number?} then asm_idiv Register::EBX
      when {"%", .is_number?, .is_number?}
        asm_idiv Register::EBX
        asm_mov Register::EAX, Register::EDX
      when {"==", .is_number?, .is_number?}
        asm_cmp Register::EAX, Register::EBX
        asm_setc Register::EAX
      else
        raise Exception.new("unimplemented: op=\"#{node.op}\" types=#{op_types.map &.to_s}")
      end
    else
      raise Exception.new("unimplemented: op=\"#{node.op}\" types=#{op_types.map &.to_s}")
    end
  end

  def calculate_address(node : AST::Node) : Nil
    case node
    when AST::Variable
      case
      when node.name?
        # Recursive call to evaluate as other type (e.g. VarDeclStmt, Param, ...)
        calculate_address(node.name.ref)
      else raise Exception.new("unhandled: #{node.inspect}")
      end
    when AST::VarDeclStmt
      comment "address for localvar {#{node.var.name}}"
      # Get pointer location of the variable.
      asm_mov Register::EAX, Register::EBP
      asm_add Register::EAX, stack_offset(node)
    else raise Exception.new("unhandled: #{node.inspect}")
    end
  end

  def visit(node : AST::ConstInteger) : Nil
      comment "load int(#{node.val})"
    asm_mov Register::EAX, node.val
  end

  def visit(node : AST::ConstBool) : Nil
    if node.val
      comment "load bool(true)"
      asm_mov Register::EAX, 1
    else
      comment "load bool(false)"
      asm_mov Register::EAX, 0
    end
  end

  def visit(node : AST::SimpleName) : Nil
    ref = node.ref
    case ref
    when AST::VarDeclStmt
      comment "fetch localvar {#{node.name}}"
      offset = stack_offset(ref)
      asm_mov Register::EAX, Register::EBP.as_address_offset(offset)
    else
      raise Exception.new("unhandled: #{node.name}")
    end
  end

  def visit(node : AST::VarDeclStmt) : Nil
    if node.var.init?
      comment "compute init for {#{node.var.name}}"
      node.var.init.accept(self)
      comment "store value into {#{node.var.name}}"
      offset = stack_offset(node)
      asm_mov Register::EBP.as_address_offset(offset), Register::EAX
    end
  end

  def stack_offset(node : AST::VarDeclStmt) : Int32
    # FIXME: (joey) support multiple locals
    -4
  end

  # def visit(node : AST::ExprRef) : Nil
    # case node.name.ref
    # when AST::VarDeclStmt
    #   comment "would be var #{node.name}"
    #   # instr
    # else raise Exception.new("unimplemented: #{node.inspect}")
    # end
  # end

end
