require "asm/file_dsl"
require "asm/register"

include ASM

# FIXME: (joey) refactor out the array logic.
BASE_ARRAY_SIZE = 4

NULL_CONST = "0xDEADBEEF"

class CodeGenerator
  include ASM::FileDSL

  property vtables : VTableMap
  property verbose : Bool
  property output_dir : String

  def initialize(@vtables : VTableMap, @verbose : Bool, @output_dir : String)
  end

  def generate(file : SourceFile)
    file.ast.accept(CodeGenerationVisitor.new(vtables, output_dir, file, @verbose))
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

      # TODO: stack pointer? what data do these initializations have access to
      files.each do |file|
        static_init_lbl = ASM::Label.from_static_init(
          file.ast.decl(file.class_name).package,
          file.class_name
        )
        extern static_init_lbl
        comment_next_line "Initialize static fields for class #{file.class_name}"
        asm_call static_init_lbl
        newline
      end

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

  property vtables : VTableMap
  property output_dir : String
  property file : SourceFile

  # A map of localvar name to stack offset.
  property! stack_variables : Hash(String, Int32)
  property! stack_size : Int32

  property if_counter : Int32 = 0
  property while_counter : Int32 = 0
  property for_counter : Int32 = 0
  property jmp_counter : Int32 = 0

  property! current_class : AST::ClassDecl
  property! current_method : AST::MethodDecl

  def initialize(@vtables : VTableMap, @output_dir : String, @file : SourceFile, @verbose : Bool)
  end

  def visit(node : AST::ClassDecl) : Nil
    source_path = @file.path
    node.inst = ClassInstance.new(node)
    self.current_class = node

    annotate "orangejoos generated Joos1W x86-32"
    annotate "interface: #{node.package}.#{node.name}" if node.is_a?(AST::InterfaceDecl)
    annotate "class: #{node.package}.#{node.name}" if node.is_a?(AST::ClassDecl)
    # FIXME(joey): This path is often munged, e.g. multiple //.
    annotate "source: #{source_path}"

    section_data
    newline

    node.static_fields.each do |field|
      global field.label
      label field.label
      comment_next_line "#{field.typ.to_s} #{field.var.name}"
      indent {
        asm_dd 0
      }
      newline
    end
    newline

    section_text
    newline
    newline

    static_init_lbl = ASM::Label.from_static_init(node.package, node.name)

    global static_init_lbl
    label static_init_lbl

    indent {
      node.static_fields.each do |field|
        field.accept(self)
        comment_next_line "save value of static field"
        asm_push Register::EAX
        comment_next_line "get location of static field"
        asm_mov Register::EAX, field.label
        comment_next_line "recover value of static field"
        asm_pop Register::EBX
        comment_next_line "assign value of static field"
        asm_mov Address.new(Register::EAX), Register::EBX
        newline
      end
      asm_ret 0
      newline
    }

    externs = ExternLabelCollector.new(node)
    @file.ast.accept(externs)

    extern ASM::Label::MALLOC
    newline
    comment "[ VTABLE LABELS ]"
    @vtables.each { |clas, table| extern table.label unless node == clas }
    comment "[ VTABLE SUPERCLASS METHODS ]"
    @vtables.exported_methods(node).each { |label| extern label }
    comment "[ CONSTRUCTOR LABELS ]"
    externs.ctors.each { |ctor| extern ctor }
    comment "[ STATIC METHOD LABELS ]"
    externs.statics.each { |static| extern static }
    newline

    indent{ section_text }
    newline

    # Generate code field initialization, used in all constructors.
    # field initializers. This creates an internal fcn and label.
    label node.inst.init_label
    indent {
      comment "ESI contains `this`"
      # TODO: (joey) support super fields. This should just be done by
      # the implicit-super call instead, inside the constructors.
      node.fields.each do |field|
        comment "initializing field #{field.name}"
        if field.var.init?
          comment "evaluating expr=#{field.var.init.to_s}"
          # Load data into EAX.
          field.var.init.accept(self)
        else
          # Initialize field to 0.
          # FIXME: (joey) make sure zero-ing is the correct action here.
          asm_mov Register::EAX, 0
        end
        comment_next_line "store into #{field.name}"
        asm_mov node.inst.field_as_address(field), Register::EAX
      end
      asm_ret 0
    }
    newline

    # Generate code for all constructors
    node.constructors.each &.accept(self)

    # Generate code for all methods.
    node.methods.each &.accept(self)

    # Generate class VTable
    indent { section_data }
    newline
    @vtables.asm(self, node)

    file_name = node.qualified_name.split(".").join("_") + ".s"
    path = File.join(output_dir, file_name)
    write_to_file(path)
  rescue ex : CompilerError
    ex.register("class_name", node.name)
    raise ex
  rescue ex : Exception
    STDERR.puts "exception in #{node.qualified_name}"
    raise ex
  end

  def visit(node : AST::MethodDecl) : Nil
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
      # Only traverse down the body. Ignore typ and params, as they do
      # not need code generation.
      # NOTE: only methods with bodies should be generated, hence the
      # `not_nil!` assert.
      node.body.each &.accept(self)
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

    if node.expr.original?
      comment "if-stmt with original expr=#{node.expr.original.to_s}"
    else
      comment "if-stmt with expr=#{node.expr.to_s}"
    end

    expr = node.expr
    if expr.is_a?(AST::ConstBool)
      if expr.val
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

  def visit(node : AST::WhileStmt) : Nil
    # while-expr-label
    while_expr_label = ASM::Label.new("while_expr_#{while_counter}")
    # while-body-label
    while_body_label = ASM::Label.new("while_body_#{while_counter}")
    # while-end-label
    while_end_label = ASM::Label.new("while_end_#{while_counter}")
    self.while_counter += 1

    if node.expr.original?
      comment "while-stmt with original expr=#{node.expr.original.to_s}"
    else
      comment "while-stmt with expr=#{node.expr.to_s}"
    end

    expr = node.expr
    if expr.is_a?(AST::ConstBool)
      if expr.val
        comment "elided while-stmt expr with expr=bool(true)"
        label while_body_label
        node.body.accept(self)
        asm_jmp while_body_label
        return
      else
        comment "elided while-stmt with expr=bool(false)"
        return
      end
    end

    # Write code for evaluting if-stmt.
    label while_expr_label
    node.expr.accept(self)
    asm_cmp Register::AL, 1
    asm_jne while_end_label

    label while_body_label
    indent do
      node.body.accept(self)
    end
    asm_jmp while_expr_label
    label while_end_label
  end

  def visit(node : AST::ForStmt) : Nil
    # for-label
    for_label = ASM::Label.new("for_#{for_counter}")
    # for-expr-label
    for_expr_label = ASM::Label.new("for_expr_#{for_counter}")
    # for-body-label
    for_body_label = ASM::Label.new("for_body_#{for_counter}")
    # for-update-label
    for_update_label = ASM::Label.new("for_update_#{for_counter}")
    # for-end-label
    for_end_label = ASM::Label.new("for_end_#{for_counter}")
    self.for_counter += 1

    # Write code for init stmt.
    label for_label
    node.init.accept(self) if node.init?
    # Write comparison expression.
    label for_expr_label
    node.expr.accept(self) if node.expr?
    asm_cmp Register::EAX, 1
    asm_jne for_end_label

    # Write for-body.
    label for_body_label
    node.body.accept(self)

    # Write for-update.
    label for_update_label
    node.update.accept(self) if node.update?

    # Jump back to the cmp expression.
    asm_jmp for_expr_label
    label for_end_label
  end

  def visit(node : AST::ExprOp) : Nil
    op_types = node.operands.map &.get_type

    if node.operands.size == 1
      # Compute sub-expression.
      node.operands[0].accept(self)
      case {node.op, node.operands[0].get_type}
        # === Numbers ===
      when {"-", .is_number_or_char?} then asm_neg Register::EAX
        # === Booleans ===
      when {"!", .is_boolean?}
        comment_next_line node.to_s
        # The ASM NOT cannot be used because it will change upper bits,
        # so this is a nice one-liner NOT:
        #   0x01 ^ 0x01 => 0x00
        #   0x00 ^ 0x01 => 0x01
        asm_xor Register::AL, 0x01
      else
        raise Exception.new("unimplemented: op=\"#{node.op}\" types=#{op_types.map &.to_s}")
      end
    elsif node.operands.size == 2
      op_sig = {node.op, node.operands[0].get_type, node.operands[1].get_type}

      # FIXME: (joey) when the LHS is for an address, we need to do
      # something specific to either keep it as an address or get the
      # value. Hence the separation between assignment and the rest.
      case {node.op, node.operands[0].get_type, node.operands[1].get_type}
      when {"=", .is_number?, .is_number?}
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
        comment_next_line  "assigning #{node.operands[0].to_s} = #{node.operands[1].to_s}"
        asm_mov Register::EBX.as_address, Register::EAX
        # NOTE: the result is in EAX, as desired as '=' is an expression.
        return
      when {"&&", .is_boolean?, .is_boolean?}
        # && and || are handled specially as they will short-circuit.
        and_short_circuit_label = ASM::Label.new("and_short_circuit_#{jmp_counter}")
        and_end_label = ASM::Label.new("and_end_#{jmp_counter}")
        self.jmp_counter += 1

        node.operands[0].accept(self)
        asm_cmp Register::EAX, 0
        asm_jne and_end_label

        node.operands[0].accept(self)
        asm_jmp and_end_label

        label and_short_circuit_label
        asm_mov Register::EAX, 0
        label and_end_label
        return
      when {"||", .is_boolean?, .is_boolean?}
        # && and || are handled specially as they will short-circuit.
        or_short_circuit_label = ASM::Label.new("or_short_circuit_#{jmp_counter}")
        or_end_label = ASM::Label.new("or_end_#{jmp_counter}")
        self.jmp_counter += 1

        node.operands[0].accept(self)
        asm_cmp Register::EAX, 1
        asm_je or_short_circuit_label

        node.operands[0].accept(self)
        asm_jmp or_end_label

        label or_short_circuit_label
        asm_mov Register::EAX, 1
        label or_end_label
        return
      end

      comment "compute LHS: #{node.operands[0].to_s}"
      # Add code for LHS.
      node.operands[0].accept(self)
      # TODO: (joey) if the operand is a constant, we can alide the load
      # and embed it into the push.
      comment_next_line "store result of first arguments"
      asm_push Register::EAX

      comment "compute RHS: #{node.operands[1].to_s}"
      node.operands[1].accept(self)
      comment_next_line "move result of second argument"
      asm_mov Register::EBX, Register::EAX

      comment_next_line "recover LHS: #{node.operands[0].to_s}"
      asm_pop Register::EAX

      # Do operations.
      # FIXME: (joey) not sure how arrays are supposed to be handled
      # here, if at all.
      case {node.op, node.operands[0].get_type, node.operands[1].get_type}
        # === Numbers ===
      when {"+", .is_number_or_char?, .is_number_or_char?} then asm_add Register::EAX, Register::EBX
      when {"-", .is_number_or_char?, .is_number_or_char?} then asm_sub Register::EAX, Register::EBX
      when {"*", .is_number_or_char?, .is_number_or_char?} then asm_imul Register::EAX, Register::EBX
        # IDIV: divide EAX by the parameter and put the quotient in EAX
        # and remainder in EDX.
      when {"/", .is_number_or_char?, .is_number_or_char?} then asm_idiv Register::EBX
      when {"%", .is_number_or_char?, .is_number_or_char?}
        asm_idiv Register::EBX
        asm_mov Register::EAX, Register::EDX
      when {"==", .is_number_or_char?, .is_number_or_char?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::Equal, Register::AL
      when {"!=", .is_number_or_char?, .is_number_or_char?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::NotEqual, Register::AL
      when {"<", .is_number_or_char?, .is_number_or_char?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::LessThan, Register::AL
      when {"<=", .is_number_or_char?, .is_number_or_char?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::LessThanEQ, Register::AL
      when {">", .is_number_or_char?, .is_number_or_char?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::GreaterThan, Register::AL
      when {">=", .is_number_or_char?, .is_number_or_char?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::GreaterThanEQ, Register::AL
        # === Booleans ===
      when {"==", .is_boolean?, .is_boolean?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::Equal, Register::AL
      when {"!=", .is_boolean?, .is_boolean?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::Equal, Register::AL
      when {"|", .is_boolean?, .is_boolean?}
        comment_next_line node.to_s
        asm_or Register::EAX, Register::EBX
      when {"&", .is_boolean?, .is_boolean?}
        comment_next_line node.to_s
        asm_and Register::EAX, Register::EBX
      when {"==", .is_object?, .is_object?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::Equal, Register::AL
      when {"!=", .is_object?, .is_object?}
        comment_next_line node.to_s
        asm_cmp Register::EAX, Register::EBX
        asm_setcc Condition::NotEqual, Register::AL
      else
        raise Exception.new("unimplemented: op=\"#{node.op}\" types=#{op_types.map &.to_s}")
      end
    else
      raise Exception.new("unimplemented: op=\"#{node.op}\" types=#{op_types.map &.to_s}")
    end
  end

  # TODO: (joey) if `calculate_address` returns the string of the address
  # for use in `mov` instructions, then this will cut down on one
  # instruction per assignment. For example:
  #
  #    mov EAX, EBP-8 ; calculate address for stack variable
  #    mov [EAX], EXPR_RESULT ; store the result into the stack address
  #
  # It will simply become:
  #
  #    mov [EBP-8], EXPR_RESULT
  #
  # The same can be done for arrays and fields in order to omit one
  # instruction.
  def calculate_address(node : AST::Node) : Nil
    case node
    when AST::Variable
      # TODO: (joey) add explicit-object field access.
      case
      when node.name?
        # Recursive call to evaluate as other type (e.g. VarDeclStmt, Param, ...)
        calculate_address(node.name.ref)
      when node.array_access?
        # Recursive call to evaluate as ArrayAccess type.
        calculate_address(node.array_access)
      else raise Exception.new("unhandled: #{node.to_s}")
      end
    when AST::VarDeclStmt
      comment_next_line "address for localvar {#{node.var.name}}"
      # Get pointer location of the variable.
      asm_mov Register::EAX, Register::EBP
      asm_add Register::EAX, stack_offset(node)
    when AST::FieldDecl
      if node.is_static?
        comment_next_line "get the label of the field"
        asm_mov Register::EAX, node.label
      else
        comment_next_line "calc field #{node.var.name} using `this`"
        asm_mov Register::EAX, Register::ESI
        asm_add Register::EAX, current_class.inst.field_offset(node)
      end
    when AST::ExprFieldAccess
      # This is when an explicit-object field access happens. This does
      # not include implicit-object field access. For example:
      #
      #    a.field
      raise Exception.new("unhandled, array.length field access: #{node}") if node.obj.get_type.is_array

      if node.field.is_static?
        comment_next_line "get the label of the field"
        asm_mov Register::EAX, node.field.label
      else
        comment "address for instance {#{node.obj.get_type.ref.name}} obj={#{node.obj.to_s}}"
        node.obj.accept(self)
        comment_next_line "calc field #{node.field_name}"
        cls = node.obj.get_type.ref.as(AST::ClassDecl)
        asm_add Register::EAX, cls.inst.field_offset(node.field)
      end
    when AST::ExprArrayAccess
      comment "calculate array ptr"
      node.expr.accept(self)
      # FIXME: (joey) I think we need to do a null check on the array
      # ptr.
      comment_next_line "save array ptr"
      asm_push Register::EAX
      comment "calcuate array idx for access"
      node.index.accept(self)
      # FIXME: (joey) I think we need to do a null check on the index.
      comment_next_line "recover array ptr"
      asm_pop Register::EBX
      # TODO: (joey) all of this arithmetic can be reduced down to a
      # single line, if the interface around ptr usage changes and if
      # the array data starts from the array pointer. If both of those
      # are changed, array data can be used as such:
      #
      #    MOV EAX, [EAX + 4*EBX] ; fetch array:EAX[index:EBX] into EAX
      #    MOV [EAX + 4*EBX], EDX ; store EDX into array:EAX[index:EBX]
      comment_next_line "multiply index offset by 4 (double-word)"
      asm_imul Register::EAX, 4
      comment_next_line "offset ptr by index and store in EAX for expr returning"
      asm_add Register::EAX, Register::EBX
    else raise Exception.new("unhandled: #{node}")
    end
  end

  def visit(node : AST::ConstInteger) : Nil
    comment_next_line "load int(#{node.val})"
    asm_mov Register::EAX, node.val
  end

  def visit(node : AST::ConstChar) : Nil
    comment_next_line "load char(#{node.val})"
    asm_mov Register::EAX, node.val.ord
  end

  def visit(node : AST::ConstNull) : Nil
    comment_next_line "load null"
    asm_mov Register::EAX, NULL_CONST
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

  def visit(node : AST::ExprRef) : Nil
    name = node.name
    if name.ref?.nil?
      return
    end
    ref = name.ref
    case ref
    when AST::VarDeclStmt
      comment_next_line "fetch localvar {#{name.name}}"
      offset = stack_offset(ref)
      asm_mov Register::EAX, Register::EBP.as_address_offset(offset)
    when AST::Param
      comment_next_line "fetch parameter {#{name.name}}"
      index = current_method.params.index(&.== ref)
      if (index.nil?)
        raise CodegenError.new("Could not find parameter #{name.name} in list")
      end
      param_count = current_method.params.size
      offset = (param_count - index) * 4
      asm_mov Register::EAX, Register::EBP.as_address_offset(offset)
    when AST::FieldDecl
      raise Exception.new("unimplemented: #{node}") unless ref.is_static?
      calculate_address(ref)
      asm_mov Register::EAX, Register::EAX.as_address
    else
      raise Exception.new("unimplemented: #{node}")
    end
  end

  def visit(node : AST::VarDeclStmt) : Nil
    if node.var.init?
      comment "compute init for {#{node.var.name}}"
      node.var.init.accept(self)
      offset = stack_offset(node)
      comment_next_line "store value into {#{node.var.name}}"
      asm_mov Register::EBP.as_address_offset(offset), Register::EAX
    end
  end

  # For doing a backup and restore step around the block of generated ASM.
  # The address of the object should be in EAX.
  def safe_call(args : Array(AST::Expr), ctor? : Bool, &block)
    # TODO: register allocation
    comment "save registers"
    asm_push Register::ESI

    unless ctor?
      comment_next_line "move address of invokee to ESI as \"this\""
      asm_mov Register::ESI, Register::EAX
    end

    args.each_with_index do |arg, idx|
      # TODO: support different argument sizes
      arg.accept(self)
      comment_next_line "Argument ##{idx}"
      asm_push Register::EAX
    end

    comment_next_line "save old base pointer"
    asm_push Register::EBP
    comment_next_line "set the new base pointer value"
    asm_mov Register::EBP, Register::ESP

    yield

    # TODO: (joey) if we change calling convention so caller saves and
    # restores EBP, then we should instead use "RET n" to de-allocate
    # the stack in one instruction.
    comment_next_line "de-allocate local variables by recovering callers ESP"
    asm_mov Register::ESP, Register::EBP
    comment_next_line "restore callers base pointer"
    asm_pop Register::EBP

    comment_next_line "remove arguments from stack"
    asm_add Register::ESP, args.size * 4

    # TODO: register allocation
    comment "restore registers"
    asm_pop Register::ESI

  end

  def visit(node : AST::MethodInvoc) : Nil
    typ = node.expr.get_type.ref.as(AST::TypeDecl)
    method = typ.method?(node.name, node.args.map &.get_type.as(Typing::Type)).not_nil!

    comment "[ Method Invocation: #{method.signature.to_s} ]"
    if method.is_static?
      safe_call(node.args, true) do
        comment_next_line "call static function"
        asm_call method.label
      end
    else
      offset = @vtables.get_offset(typ, method.signature)
      node.expr.accept(self) if node.expr.get_type.is_object? # puts the address of the object in EAX

      safe_call(node.args, false) do
        comment_next_line "load vptr"
        asm_mov  Register::EAX, Register::ESI.as_address_offset(VPTR_OFFSET)
        comment_next_line "call vtable function at offset"
        asm_call Register::EAX, offset
      end
    end
  end

  def visit(node : AST::CastExpr) : Nil
    cast_typ = node.typ.to_type
    from_typ = node.rhs.get_type
    if from_typ.equiv(cast_typ)
      # Elide the cast and just emit the expression logic because this
      # is a same-type cast which will contain no logic.
      node.rhs.accept(self)
    elsif cast_typ.is_array || from_typ.is_array
      # Unhandled: casts involving arrays
      raise Exception.new("unimplemented, casts involving arrays: cast=#{cast_typ.to_s} from=#{from_typ.to_s}")
    elsif cast_typ.typ == Typing::Types::CHAR && from_typ.typ == Typing::Types::INT
      # Truncate to 1 byte.
      node.rhs.accept(self)
      asm_and Register::EAX, 0xFF
    elsif cast_typ.is_number? &&
      # load the RHS expr
      node.rhs.accept(self)
      if cast_typ.typ == Typing::Types::BYTE || from_typ.typ == Typing::Types::BYTE
        # Truncate to 1 byte.
        asm_and Register::EAX, 0xFF
      elsif cast_typ.typ == Typing::Types::SHORT || from_typ.typ == Typing::Types::SHORT
        # Truncate to 2 bytes.
        asm_and Register::EAX, 0xFFFF
      else
        # Do nothing. Casting from an INT to INT will do nothing.
      end
    else
      raise Exception.new("unimplemented, casts for: cast=#{cast_typ.to_s} from=#{from_typ.to_s}")
    end
  end

  def stack_offset(node : AST::VarDeclStmt) : Int32
    # NOTE: the offset is shifted by -8, _BASE_OFFSET_, as the first
    # item on the EBP is the caller's EIP. This is a byproduct of the
    # caller setting the EBP prior to calling without offsetting it.
    # TODO: (joey) not sure why it's -8 instead of -4...
    base_offset = -8
    return base_offset - stack_variables[node.var.name]
  end

  def visit(node : AST::File) : Nil
    # Do not visit packages or imports.
    node.decls.each &.accept(self)
  end

  def visit(node : AST::ConstructorDecl) : Nil
    raise Exception.new("unimplemented, constructor with >0 params: #{node}") if node.params.size > 0
    cls = node.parent.as(AST::ClassDecl)
    method(node.label) do
      comment_next_line "malloc #{cls.inst.size} bytes for instance of #{cls.qualified_name}"
      # FIXME: (joey) once we handle arguments, save any args in EAX and
      # EBX as MALLOC trample them.
      asm_mov Register::EAX, cls.inst.size
      asm_call ASM::Label::MALLOC
      comment_next_line "load the address of the vtable into the ptr"
      asm_mov Register::EAX.as_address, @vtables.label(cls), Size::DWORD
      comment_next_line "add 4 to the instance ptr to account for vptr"
      asm_add Register::EAX, 4
      comment_next_line "move the instance ptr to ESI (as `this`)"
      asm_mov Register::ESI, Register::EAX
      # FIXME: (joey) execute super constructor.
      comment_next_line "initialize instance fields"
      asm_call cls.inst.init_label
      comment "execute constructor contents"
      node.body.each &.accept(self)

      # Put the instance ptr into EAX as the return value.
      asm_mov Register::EAX, Register::ESI

      asm_ret 0
    end
  end

  def visit(node : AST::InterfaceDecl) : Nil
    # We do not want to traverse through any content of an InterfaceDecl.
    # no super
  end

  def visit(node : AST::ExprClassInit) : Nil
    safe_call(node.args, true) do
      asm_call node.constructor.label
    end
  end

  def visit(node : AST::ExprArrayInit) : Nil
    comment "calculate array expr={#{node.dim.to_s}}"
    node.dim.accept(self)
    # FIXME: (joey) I think we need to assert EAX is > 0 at runtime.
    comment_next_line "save array size"
    asm_push Register::EAX
    comment_next_line "add base-array size for final size"
    asm_add Register::EAX, BASE_ARRAY_SIZE
    comment_next_line "allocate the array"
    asm_call ASM::Label::MALLOC
    comment_next_line "pop computed array size"
    asm_pop Register::EBX
    comment_next_line "set the psuedo-field array.length"
    asm_mov Register::EAX.as_address, Register::EBX
    comment_next_line "shift the array ptr so the first item is data"
    asm_add Register::EAX, BASE_ARRAY_SIZE
    comment "ExprArrayInit returning ptr in EAX"
    # FIXME: (joey) do we need to zero initialize the data? It may be
    # zero'd by malloc. as EAX.
  end

  def visit(node : AST::ExprThis) : Nil
    # This maintains the invariant that an expression will put the result
    # into EAX.
    # TODO: (joey) this is pretty inefficient, but is the lazy way to
    # "return" the instance ptr for use further up the AST with the
    # "expr returns EAX" invariant.
    comment_next_line "load `this`"
    asm_mov Register::EAX, Register::ESI
  end

  def visit(node : AST::ExprFieldAccess) : Nil
    if node.obj.get_type.is_array
      comment "get address for array {#{node.obj.to_s}}"
      node.obj.accept(self)
      # FIXME: (joey) I think we need to do a null check before accessing
      # the field.
      comment_next_line "fetch array.length for array {#{node.obj.to_s}}"
      asm_mov Register::EAX, Register::EAX.as_address_offset(-4)
    elsif node.field.is_static?
      calculate_address(node)
      asm_mov Register::EAX, Register::EAX.as_address
    else
      cls = node.obj.get_type.ref.as(AST::ClassDecl)
      offset = cls.inst.field_offset(node.field)

      comment "address for instance {#{node.obj.get_type.ref.name}} obj={#{node.obj.to_s}}"
      node.obj.accept(self)
      # FIXME: (joey) I think we need to do a null check before accessing
      # the field.
      comment_next_line "calc field #{node.field_name}"
      asm_mov Register::EAX, Register::EAX.as_address_offset(offset)
    end
  end

  def visit(node : AST::ExprArrayAccess) : Nil
    comment "call calculate_address(ArrayAccess)"
    calculate_address(node)
    comment_next_line "fetch data for expr={#{node.to_s}}"
    asm_mov Register::EAX, Register::EAX.as_address
  end

  # These are all the nodes that we do not require an implementation
  # for.

  # abstract def visit(node : AST::Block) : Nil

  # These are all the notes that are unimplemented, and should raise a
  # loud error upon encountering.

  def visit(node : AST::PrimitiveTyp) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::ClassTyp) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::Identifier) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::PackageDecl) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::ImportDecl) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::Modifier) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::QualifiedName) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::FieldDecl) : Nil
    node.var.init.accept(self)
  end

  def visit(node : AST::Param) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::ExprInstanceOf) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::ConstString) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::SimpleName) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::ParenExpr) : Nil
    raise Exception.new("unimplemented: #{node}")
  end

  def visit(node : AST::Variable) : Nil
    raise Exception.new("unimplemented: #{node}")
  end


end

class ExternLabelCollector < Visitor::GenericVisitor
  getter ctors = Array(ASM::Label).new
  getter statics = Array(ASM::Label).new

  def initialize(@node : AST::ClassDecl)

  end

  def visit(node : AST::ExprClassInit)
    ctors.push(node.constructor.label) # if !@node.method?(node.constructor)
  end

  def visit(node : AST::MethodInvoc)
    method_decl = node.method_decl
    statics.push(method_decl.label) if !@node.method?(method_decl) && method_decl.is_static?
  end
end
