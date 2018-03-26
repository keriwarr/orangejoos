module Typing
  enum Types
    CHAR
    INT
    SHORT
    BYTE
    BOOLEAN
    NULL

    VOID

    INSTANCE
    STATIC
  end

  PRIMITIVES        = [Types::CHAR, Types::INT, Types::SHORT, Types::BYTE, Types::BOOLEAN, Types::NULL]
  NUMBERS_WITH_CHAR = [Types::INT, Types::SHORT, Types::BYTE, Types::CHAR]
  NUMBERS           = [Types::INT, Types::SHORT, Types::BYTE]

  # This is a short-hand for referring to the non-built-in String type.
  def self.get_string_type(namespace)
    string_class = namespace.fetch(AST::QualifiedName.new(["java", "lang", "String"]))
    if string_class.nil?
      raise Exception.new("could not find java.lang.String to resolve for String literal")
    end
    return Typing::Type.new(Typing::Types::INSTANCE, string_class.not_nil!)
  end

  # Handles type conversions for casting operations, including:
  # - Casting
  # - Equality (==, !=)
  def self.can_cast_type(from : Type, to : Type) : Bool
    return true if _can_change_type(from, to)

    # Allow casts between numeric types (including chars).
    return true if NUMBERS_WITH_CHAR.includes?(from.typ) && NUMBERS_WITH_CHAR.includes?(to.typ) && from.is_array == to.is_array

    # Special case: conversion from Object to Object[].
    return true if from.is_object? && !from.is_array && to.is_object? && to.is_array && from.ref.as(AST::TypeDecl).qualified_name == "java.lang.Object" && to.ref.as(AST::TypeDecl).qualified_name == "java.lang.Object"

    if from.is_object? && from.ref.is_a?(AST::InterfaceDecl) && to.is_object?
      from_interface = from.ref.as(AST::InterfaceDecl)
      # From any interface J to any interface K if J is a subinterface of K.
      return true if to.ref.is_a?(AST::InterfaceDecl) &&
                     to.ref.as(AST::InterfaceDecl).extends?(from.ref.as(AST::InterfaceDecl))
    end

    if from.is_object? && to.is_object?
      # Between Object and any type.
      return true if from.ref.as(AST::TypeDecl).qualified_name == "java.lang.Object" || to.ref.as(AST::TypeDecl).qualified_name == "java.lang.Object"

      # From any class S to an interface K, if the class S implements the
      # interface K.
      return true if from.ref.is_a?(AST::ClassDecl) && to.ref.is_a?(AST::InterfaceDecl) &&
                     from.ref.as(AST::ClassDecl).implements?(to.ref.as(AST::InterfaceDecl))

      # From any class S to another class T, if S is a subclass of T.
      # (Special case to Object).
      return true if from.ref.is_a?(AST::ClassDecl) && to.ref.is_a?(AST::ClassDecl) &&
                     from.ref.as(AST::ClassDecl).extends?(to.ref.as(AST::ClassDecl))

      # From any class S to another class T, if S is a superclass of T.
      # (Special case to Object).
      return true if to.ref.is_a?(AST::ClassDecl) && from.ref.is_a?(AST::ClassDecl) &&
                     to.ref.as(AST::ClassDecl).extends?(from.ref.as(AST::ClassDecl))

      # Special case: conversion from Object to Object[].
      return true if from.ref.as(AST::TypeDecl).qualified_name == "java.lang.Object" && to.ref.as(AST::TypeDecl).qualified_name == "java.lang.Object"
    end
    return false
  end

  # Handles type conversions for type assignments, including:
  # - Varible decls
  # - Field decls
  # - Assignment operation
  # - Return statements
  def self.can_assign_type(from : Type, to : Type) : Bool
    # Only allow upcasting numeric assignments (similarily for arrays).
    # Do not allow assignments such as:
    #    byte <- int
    #    short <- int
    if from.is_number? && to.is_number? && from.is_array == to.is_array
      # Only allow int <- int, not:
      #   {byte,short} <- int
      return false if from.typ == Types::INT && to.typ != Types::INT
      # Only allow {short, int} <- short, not:
      #   byte <- short
      return false if from.typ == Types::SHORT && to.typ == Types::BYTE
      # Disallow int[] <- byte[]. int <- byte is allowed though.
      return false if from.typ == Types::BYTE && to.typ == Types::INT && from.is_array && to.is_array
    end

    return _can_change_type(from, to)
  end

  def self._can_change_type(from : Type, to : Type) : Bool
    return true if from == to

    # From null to any class, interface, or array type.
    return true if from.typ == Types::NULL && (to.is_object? || to.is_array)

    # From any interface/class type (any dimension) to Object.
    return true if (from.is_object? || from.is_array) && !to.is_array && to.ref.as(AST::TypeDecl).qualified_name == "java.lang.Object"

    # From array type to Object, Cloneable, or java.io.Serializable.
    return true if from.is_array && to.is_object? && !to.is_array && ["java.lang.Object", "java.io.Serializable", "java.lang.Cloneable"].includes?(to.ref.as(AST::TypeDecl).qualified_name)

    # Everything after must have same array-ness.
    return false if from.is_array != to.is_array

    # Allow casts between numeric types (not including chars), that are not arrays.
    return true if !from.is_array && from.is_number? && to.is_number? && to.typ != Typing::Types::CHAR && from.typ != Typing::Types::CHAR

    # Allow casts from char to int, that are not arrays.
    return true if !from.is_array && from.is_type?(Types::CHAR) && to.typ == Types::INT

    # Most of these rules are for 5.1.4 Widening Reference Conversions

    if from.is_object? && from.ref.is_a?(AST::InterfaceDecl) && to.is_object?
      from_interface = from.ref.as(AST::InterfaceDecl)

      # From any interface J to any interface K if J is a subinterface of K.
      return true if to.ref.is_a?(AST::InterfaceDecl) &&
                     to.ref.as(AST::InterfaceDecl).extends?(from.ref.as(AST::InterfaceDecl))
    end

    if from.is_object? && to.is_object?
      # From any class S to another class T, if S is a subclass of T.
      # (Special case to Object).
      return true if from.ref.is_a?(AST::ClassDecl) && to.ref.is_a?(AST::ClassDecl) &&
                     from.ref.as(AST::ClassDecl).extends?(to.ref.as(AST::ClassDecl))

      # # From any class S to another class T, if S is a superclass of T.
      # # (Special case to Object).
      # return true if to.ref.is_a?(AST::ClassDecl) && from.ref.is_a?(AST::ClassDecl) &&
      #                to.ref.as(AST::ClassDecl).extends?(from.ref.as(AST::ClassDecl))
    end

    return false
  end

  class Type
    property typ : Types
    property! ref : AST::TypeDecl
    property is_array : Bool = false

    def ref : AST::TypeDecl
      if !@ref.nil?
        return @ref.not_nil!
      end
      raise Exception.new("ref not evaluated for #{typ}")
    end

    def initialize(@typ : Types)
      if [Types::INSTANCE, Types::STATIC].includes?(@typ)
        raise Exception.new("initializing with INSTANCE or STATIC without a ref type")
      end
    end

    def initialize(@typ : Types, @is_array : Bool)
    end

    def initialize(@typ : Types, @ref : AST::TypeDecl)
    end

    def initialize(@typ : Types, @ref : AST::TypeDecl, @is_array : Bool)
    end

    def from_array_type : Type
      raise Exception.new("cannot dereference non-array type") if !is_array
      return Type.new(typ, ref, false) if ref?
      return Type.new(typ, false)
    end

    def to_array_type : Type
      raise Exception.new("cannot nest array type") if is_array
      return Type.new(typ, ref, true) if ref?
      return Type.new(typ, true)
    end

    def is_type?(s : Types) : Bool
      # This is because of the comparisons below in `#==` use
      # `other.ref`, which will be nil and hit a nil assertion.
      raise Exception.new("you cannot do this. use is_object? instead") if s == Types::INSTANCE
      raise Exception.new("you cannot do this. use is_static? instead") if s == Types::STATIC
      return self == (Typing::Type.new(s))
    end

    def is_primitive? : Bool
      return PRIMITIVES.includes?(typ)
    end

    def is_object? : Bool
      return typ == Types::INSTANCE
    end

    def is_static? : Bool
      return typ == Types::STATIC
    end

    def is_number? : Bool
      return NUMBERS.includes?(typ)
    end

    def ==(other : Type) : Bool
      # When both are not arrays, instatly false.
      return false if other.is_array != self.is_array
      # When both are reference types and the same.
      if other.typ == self.typ && [Types::INSTANCE, Types::STATIC].includes?(self.typ)
        return other.ref.qualified_name == self.ref.qualified_name
      end
      # When both are the same primative types (i.e. non-reference)
      return true if other.typ == self.typ
      # When both are numerical types.
      return true if NUMBERS.includes?(other.typ) && NUMBERS.includes?(self.typ)
      return false
    end

    def equiv(other : Type) : Bool
      return false unless self.typ == other.typ
      return false unless self.ref? == other.ref?
      return false unless self.is_array == other.is_array
      return true
    end

    def to_s : String
      return "<Type \"#{typ} #{ref?.try &.qualified_name} #{is_array} \">"
    end
  end

  module Typed
    property! evaluated_typ : Type

    def get_type(namespace : ImportNamespace) : Type
      if !evaluated_typ?
        # This is done to assert `resolve_type` signature is (Type). If
        # the user forgets to return, it accidentally becomes
        # `Type?`.
        typ : Type = resolve_type(namespace)
        evaluated_typ = typ
      end
      return evaluated_typ.not_nil!
    end

    abstract def resolve_type(namespace : ImportNamespace) : Type
  end
end

class TypeCheck
  def initialize(@file : SourceFile, @verbose : Bool)
  end

  def check
    @file.ast.accept(StaticThisCheckVisitor.new)
    @file.ast.accept(DefaultCtorCheckVisitor.new)
    @file.ast.accept(TypeResolutionVisitor.new(@file.import_namespace))
    @file.ast.accept(StmtTypeCheckVisitor.new(@file.import_namespace))
    @file.ast.accept(FieldInitCheckVisitor.new)
  end
end

# `TypeResolutionVisitor` resolves all expression types. If there is a
# type issues, an exception is raised by an AST's `resolve_type` method.
class TypeResolutionVisitor < Visitor::GenericVisitor
  def initialize(@namespace : ImportNamespace)
  end

  def visit(node : AST::ClassDecl)
    @namespace.current_class = node
    super
  rescue ex : CompilerError
    ex.register("class_name", node.name)
    raise ex
  end

  def visit(node : AST::Expr) : Nil
    node.get_type(@namespace)
    super
  end
end

# `StaticThisCheckVisitor` checks that there are no references to `this`
# inside static methods or fields bodies.
class StaticThisCheckVisitor < Visitor::GenericVisitor
  property! current_class_name : String
  property! current_parent_name : String

  def visit(node : AST::ConstructorDecl)
    # Do not traverse down constructor bodies.
    # no super
  end

  def visit(node : AST::ClassDecl)
    current_class_name = node.qualified_name
    super
  end

  def visit(node : AST::FieldDecl | AST::MethodDecl)
    current_parent_name = node.name
    # Only check static fields or methods.
    super if node.has_mod?(AST::Modifier::STATIC)
  end

  # We only traverse down static bodies, meaning we will only encounter
  # _this_ expressions inside static bodies.
  def visit(node : AST::ExprThis)
    raise TypeCheckStageError.new("cannot use 'this' inside static #{current_parent_name} in class #{current_class_name}")
  end
end

# `DefaultCtorCheckVisitor` checks if all classes have the
# default constructor defined. This is a Joos1W requirement.
class DefaultCtorCheckVisitor < Visitor::GenericVisitor
  property! has_default_constructor : Bool

  def visit(node : AST::ClassDecl) : Nil
    self.has_default_constructor = false
    super
    if !self.has_default_constructor && node.is_inherited
      raise TypeCheckStageError.new("class #{node.qualified_name} does not have default constructor and is a superclass")
    end
  end

  def visit(node : AST::ConstructorDecl) : Nil
    self.has_default_constructor = true if node.signature.equiv(AST::MethodSignature.constructor([] of Typing::Type))
  end
end

# `FieldInitCheckVisitor` checks that the initializers for fields are
# well-formed. This checks:
#
# - If another field is accessed within an initializer, it must appear
#   before this field. Except when:
#
#   - The field is assigned earlier in an expression, and is not the
#     current field.
class FieldInitCheckVisitor < Visitor::GenericVisitor
  property! accessible_fields : Array(String)
  property! class_name : String
  property! field_name : String

  def visit(node : AST::InterfaceDecl | AST::PackageDecl | AST::ImportDecl) : Nil
    # no super
  end

  def visit(node : AST::ClassDecl) : Nil
    self.accessible_fields = [] of String
    self.class_name = node.qualified_name
    node.fields.map &.accept(self)
    # no super
  end

  def visit(node : AST::FieldDecl) : Nil
    self.field_name = node.name
    if !node.has_mod?(AST::Modifier::STATIC)
      super
      self.accessible_fields.push(node.name)
    end
  end

  def visit(node : AST::ExprOp) : Nil
    if node.op == "="
      lhs = node.operands[0]
      # If the LHS is a field variable, then consider it an accessible
      # field.
      if lhs.is_a?(AST::Variable) && lhs.name?
        ref = lhs.name.ref
        if ref.is_a?(AST::FieldDecl)
          # Do not allow access after assignment if the assignment is to
          # the current field.
          if ref.name != self.field_name
            self.accessible_fields.push(ref.name)
          end
        end
      end
      node.operands[1].accept(self)
    else
      super
    end
  end

  def visit(node : AST::SimpleName) : Nil
    return unless node.ref.is_a?(AST::FieldDecl)
    # Check if the field is currently accessible.
    if !self.accessible_fields.includes?(node.name)
      raise TypeCheckStageError.new("used field {#{node.name}} before initialization in #{self.class_name}.#{self.field_name}")
    end
  end
end

# `StmtTypeCheckVisitor` checks that all statements have valid type
# inputs. For example, a for loops comparison expression must evaluate
# to a boolean. This includes:
# - For loop comparison clause.
# - While loop comparison clause.
# ...
class StmtTypeCheckVisitor < Visitor::GenericVisitor
  def initialize(@namespace : ImportNamespace)
  end

  def visit(node : AST::ClassDecl)
    @namespace.current_class = node
    super
  end

  def visit(node : AST::MethodDecl) : Nil
    @namespace.current_method_name = node.name
    @namespace.current_method_typ = node.typ?.try &.to_type
    super
  end

  def visit(node : AST::ConstructorDecl) : Nil
    @namespace.current_method_name = node.name
    @namespace.current_method_typ = nil

    super
  end

  def visit(node : AST::ForStmt) : Nil
    if node.expr? && !node.expr.get_type(@namespace).is_type?(Typing::Types::BOOLEAN)
      raise TypeCheckStageError.new("for-loop comparison clause is not a bool, instead got: #{node.expr.get_type(@namespace).to_s}")
    end
    super
  end

  def visit(node : AST::IfStmt) : Nil
    if !node.expr.get_type(@namespace).is_type?(Typing::Types::BOOLEAN)
      raise TypeCheckStageError.new("if clause is not a bool, instead got: #{node.expr.get_type(@namespace).to_s}")
    end
    super
  end

  def visit(node : AST::WhileStmt) : Nil
    if !node.expr.get_type(@namespace).is_type?(Typing::Types::BOOLEAN)
      raise TypeCheckStageError.new("while-loop comparison clause is not a bool, instead got: #{node.expr.get_type(@namespace).to_s}")
    end
    super
  end

  def visit(node : AST::VarDeclStmt) : Nil
    init_typ = node.var.init.get_type(@namespace)
    typ = node.typ.to_type
    if !Typing.can_assign_type(init_typ, typ)
      raise TypeCheckStageError.new("variable decl #{node.var.name} types wrong: expected {#{typ.to_s}} got #{node.var.init.get_type(@namespace).to_s}")
    end
    super
  end

  def visit(node : AST::FieldDecl) : Nil
    if node.var.init?
      init_typ = node.var.init.get_type(@namespace)
      typ = node.typ.to_type
      if !Typing.can_assign_type(init_typ, typ)
        raise TypeCheckStageError.new("variable decl #{node.var.name} types wrong: expected {#{typ.to_s}} got #{node.var.init.get_type(@namespace).to_s}")
      end
    end
    super
  end

  def visit(node : AST::ReturnStmt) : Nil
    return_typ = node.expr?.try &.get_type(@namespace)
    method_name = @namespace.current_method_name
    method_typ = @namespace.current_method_typ
    if method_typ.nil?
      raise TypeCheckStageError.new("method #{method_name} is void but returning #{return_typ.try &.to_s}") if !return_typ.nil?
    else
      raise TypeCheckStageError.new("method #{method_name} has empty return, expected #{method_typ.try &.to_s}") if return_typ.nil?
      if !Typing.can_assign_type(return_typ, method_typ)
        raise TypeCheckStageError.new("method #{method_name} is returning #{return_typ.try &.to_s}, expected #{method_typ.try &.to_s}")
      end
    end
    super
  end
end
