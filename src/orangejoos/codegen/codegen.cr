require "asm/file_dsl"
require "asm/register"

include ASM

class CodeGenerator
  include ASM::FileDSL

  property vtable : VTable
  property verbose : Bool
  property output_dir : String

  def initialize(@vtable : VTable, @verbose : Bool, @output_dir : String)
  end

  def generate(file : SourceFile)
    file.ast.accept(CodeGenerationVisitor.new(output_dir, file, @verbose))
  end

  def generate_entry(files : Array(SourceFile))
    entry_fcn = find_entry_fcn(files)
    entry_label = entry_fcn.label

    macos_start_lbl = Label.new("start")
    linux_start_lbl = Label.new("_start")
    exit_lbl = Label.new("_exit")

    annotate "Joos1W program entry"
    indent {
      section_text
      newline
      newline
      extern entry_label
      newline
      comment_next_line "MacOS (macho) entry point"
      global macos_start_lbl
      comment_next_line "Linux (elf_i386) entry point"
      global linux_start_lbl
    }

    label macos_start_lbl
    label linux_start_lbl
    indent {
      comment_next_line "set up initial EBP"
      asm_mov Register::EBP, Register::ESP
      asm_call entry_label
      comment_next_line "The status code is returned into EAX, which exit() uses."
      asm_call exit_lbl
    }
    newline

    comment_next_line "exit(status : Int) - status is stored in EAX"
    label exit_lbl
    indent {
      comment "Call the syscall sys_exit(status)."
      newline
      raw "%ifidn __OUTPUT_FORMAT__, macho\n"
      newline
      comment "The BSD semantics for syscalls is that arguments are pushed to the stack."
      comment_next_line "push the exit static code for the syscall arg."
      asm_push Register::EAX
      comment_next_line "denotes syscall 1, sys_exit(status)."
      asm_mov Register::EAX, 1
      comment_next_line "?? not sure what this is for and why. it is part of how systcall work."
      asm_push Register::EAX
      comment_next_line "enter the syscall interrupt."
      asm_int 128
      newline
      raw "%elifidn __OUTPUT_FORMAT__, elf\n"
      newline
      comment "exit code. Linux semantics is arguments are put into registers on syscalls."
      comment_next_line "Move the argument (status) to EBX"
      asm_mov Register::EBX, Register::EAX
      comment_next_line "syscall 1, exit(status)"
      asm_mov Register::EAX, 1
      comment_next_line "enter the syscall interrupt."
      asm_int 128
      newline
      raw "%else\n"
      newline
      raw "  %error unimplemented for output format __OUTPUT_FORMAT__\n"
      newline
      raw "%endif\n"
      newline
    }

    entry_path = File.join(output_dir, "__entry.s")
    write_to_file(entry_path)
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
  property variables : Array(AST::VarDeclStmt) = Array(AST::VarDeclStmt).new

  def initialize(@variable_offsets : Hash(String, Int32))
  end

  def visit(node : AST::VarDeclStmt) : Nil
    self.variables.push(node)
  end

  def on_completion
    offset = 0
    self.variables.each do |decl|
      # TODO: (joey) for now every type supported is a double-word
      # (32bits). For Joos1W, we may not need to support other sized
      # types.
      @variable_offsets[decl.var.name] = offset
      offset += 4
    end
  end
end

# `CodeCreationVisitor`
# FIXME(joey): CodeGenerationVisitor can only handle files with a single
# entity. We will need to change this DSL/generator to handle otherwise.
class CodeGenerationVisitor < Visitor::GenericVisitor
  include ASM::FileDSL

  property output_dir : String
  property file : SourceFile

  # A map of localvar name to stack offset.
  property! stack_variables : Hash(String, Int32)
  property! stack_size : Int32

  property if_counter : Int32 = 0

  property! current_method : AST::MethodDecl

  def initialize(@output_dir : String, @file : SourceFile, @verbose : Bool)
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
      STDERR.puts "unimplemented: non-static methods. not compiling #{node.parent.qualified_name} {#{node.name}}" if @verbose
      return
    end

    self.current_method = node

    # Collect all stack variables and their stack offsets.
    self.stack_variables = Hash(String, Int32).new
    node.accept(LocalVariableCollector.new(stack_variables))
    # TODO: (joey) this assumes every variale is a double-word size.
    self.stack_size = self.stack_variables.sum { |_| 4 }

    method(node.label) do
      # Initialize the stack frame of the method. This involves
      # initializing the stack data for local variables.
      stack_variables.each do |var, size|
        # TODO: (joey) for now every type supported is a double-word
        # (32bits). For Joos1W, we may not need to support other sized
        # types.
        # TODO: (joey) we may not need to `PUSH 0`, and we may just be
        # able to do a one-shot SUB offset as memory may not need to be
        # zero'd. Realistically, all variables require an initializer so
        # it will be initialized on the block entry.
        comment_next_line "init space for localvar {#{var}}"
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
    # When we return we discard the localvars on the stack so that the
    # top item on the stack is EIP for returning.
    asm_add Register::ESP, self.stack_size
    # TODO: (joey) we can add one "method$...$ret" label at the end of
    # the method where we only need to have the common end instructions
    # once.
    # TODO: (joey) we can change the "ret" call to also pop off
    # arguments passed in if the arguments are the last thing pushed.
    # Right now, EBP is after them.
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
    asm_cmp Register::AL, 1

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
      # TODO: (joey) if the operand is a constant, we can alide the load
      # and embed it into the push.
      comment_next_line "store result of first arguments"
      asm_push Register::EAX

      comment_next_line "compute RHS: #{node.operands[1].to_s}"
      node.operands[1].accept(self)
      comment_next_line "move result of second argument"
      asm_mov Register::EBX, Register::EAX

      comment_next_line "recover LHS: #{node.operands[0].to_s}"
      asm_pop Register::EAX

      # Do operations.
      case {node.op, node.operands[0].get_type, node.operands[1].get_type}
      when {"+", .is_number?, .is_number?} then asm_add Register::EAX, Register::EBX
      when {"-", .is_number?, .is_number?} then asm_sub Register::EAX, Register::EBX
      when {"*", .is_number?, .is_number?} then asm_imul Register::EAX, Register::EBX
        # IDIV: divide EAX by the parameter and put the quotient in EAX
        # and remainder in EDX.
      when {"/", .is_number?, .is_number?} then asm_idiv Register::EBX
      when {"%", .is_number?, .is_number?}
        asm_idiv Register::EBX
        asm_mov Register::EAX, Register::EDX
      when {"==", .is_number?, .is_number?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::Equal, Register::AL
      when {"<", .is_number?, .is_number?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::LessThan, Register::AL
      when {"<=", .is_number?, .is_number?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::LessThanEQ, Register::AL
      when {">", .is_number?, .is_number?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::GreaterThan, Register::AL
      when {">=", .is_number?, .is_number?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::GreaterThanEQ, Register::AL
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
      comment_next_line "address for localvar {#{node.var.name}}"
      # Get pointer location of the variable.
      asm_mov Register::EAX, Register::EBP
      asm_add Register::EAX, stack_offset(node)
    else raise Exception.new("unhandled: #{node.inspect}")
    end
  end

  def visit(node : AST::ConstInteger) : Nil
    comment_next_line "load int(#{node.val})"
    asm_mov Register::EAX, node.val
  end

  def visit(node : AST::ConstBool) : Nil
    if node.val
      comment_next_line "load bool(true)"
      asm_mov Register::EAX, 1
    else
      comment_next_line "load bool(false)"
      asm_mov Register::EAX, 0
    end
  end

  def visit(node : AST::SimpleName) : Nil
    if node.ref?.nil?
      return
    end
    ref = node.ref
    case ref
    when AST::VarDeclStmt
      comment_next_line "fetch localvar {#{node.name}}"
      offset = stack_offset(ref)
      asm_mov Register::EAX, Register::EBP.as_address_offset(offset)
    when AST::Param
      comment_next_line "fetch parameter {#{node.name}}"
      index = current_method.params.index(&.== ref)
      if (index.nil?)
        raise CodegenError.new("Could not find parameter #{node.name} in list")
      end
      param_count = current_method.params.size
      offset = (param_count - index) * 4
      asm_mov Register::EAX, Register::EBP.as_address_offset(offset)
    end
  end

  def visit(node : AST::VarDeclStmt) : Nil
    if node.var.init?
      comment "compute init for {#{node.var.name}}"
      node.var.init.accept(self)
      comment_next_line "store value into {#{node.var.name}}"
      offset = stack_offset(node)
      asm_mov Register::EBP.as_address_offset(offset), Register::EAX
    end
  end

  def visit(node : AST::MethodInvoc) : Nil
    typ = node.expr.get_type.ref.as(AST::TypeDecl)
    method = typ.method?(node.name, node.args.map &.get_type.as(Typing::Type)).not_nil!
    label = ASM::Label.from_method(method.parent.package, method.parent.name, method.name, method.params.map { |p| p.typ.to_type.to_s })

    # TODO: register allocation
    # comment_next_line "Save all the registers. This is lazy and can be optimized"
    # asm_pushad

    node.args.each_with_index do |arg, idx|
      # TODO: support different argument sizes
      arg.accept(self)
      comment_next_line "Argument ##{idx}"
      asm_push Register::EAX
    end

    comment_next_line "save old base pointer"
    asm_push Register::EBP
    comment_next_line "set the new base pointer value"
    asm_mov Register::EBP, Register::ESP

    asm_call label

    # TODO: (joey) if we change calling convention so caller saves and
    # restores EBP, then we should instead use "RET n" to de-allocate
    # the stack in one instruction.
    comment_next_line "de-allocate local variables by recovering callers ESP"
    asm_mov Register::ESP, Register::EBP
    comment_next_line "restore callers base pointer"
    asm_pop Register::EBP

    comment_next_line "remove arguments from stack"
    asm_add Register::ESP, node.args.size * 4

    # TODO: register allocation
    # comment_next_line "Restore all the registers"
    # asm_popad
  end

  def visit(node : AST::CastExpr) : Nil
    cast_typ = node.typ.to_type
    if node.rhs.get_type.equiv(cast_typ)
      # Elide the cast and just emit the expression logic because this
      # is a same-type cast which will contain no logic.
      node.rhs.accept(self)
    elsif cast_typ.is_number?
      # load the RHS expr
      node.rhs.accept(self)
      if cast_typ.typ == Typing::Types::BYTE || node.rhs.get_type.typ == Typing::Types::BYTE
        # Truncate to 1 byte. Not actually sure what this magical
        # constant does or how.
        asm_and Register::EAX, 0xFF
      elsif cast_typ.typ == Typing::Types::SHORT || node.rhs.get_type.typ == Typing::Types::SHORT
        # Truncate to 2 bytes.
        asm_and Register::EAX, 0xFFFF
      else
        # Do nothing. Casting from an INT to INT will do nothing.
      end
    else
      raise Exception.new("unimplemented, cast for non-number: #{node.inspect}")
    end
  end

  def stack_offset(node : AST::VarDeclStmt) : Int32
    # NOTE: the offset is shifted by -8, _BASE_OFFSET_, as the first
    # item on the EBP is the caller's EIP. This is a byproduct of the
    # caller setting the EBP prior to calling without offsetting it.
    # FIXME: (joey) not sure why it's -8 instead of -4...
    base_offset = -8
    return base_offset - stack_variables[node.var.name]
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
