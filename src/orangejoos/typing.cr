module Typing
  enum Types
    CHAR
    NUM
    INT
    SHORT
    BYTE
    BOOLEAN
    NULL

    REFERENCE
    STATIC

    # FIXME(joey): Remove usage.
    TODO
  end

  PRIMITIVES = [Types::CHAR, Types::NUM, Types::INT, Types::SHORT, Types::BYTE, Types::BOOLEAN, Types::NULL]

  def self.can_convert_type(from : Type, to : Type) : Bool
    return true if from == to

    return true if from.is_type?(Types::NUM) && to.is_type?(Types::NUM)

    # 5.1.4 Widening Reference Conversions

    # From null to any class, interface, or array type.
    return true if from.is_type?(Types::NULL) && (to.is_object? || to.is_array)

    # From array type to Object, Cloneable, or java.io.Serializable.
    return true if from.is_array && to.is_object? && ["java.lang.Object", "java.io.Serializable", "java.lang.Cloneable"].includes?(to.ref.as(AST::TypeDecl).qualified_name)

    if from.is_object? && from.ref.is_a?(AST::InterfaceDecl) && to.is_object?
      from_interface = from.ref.as(AST::InterfaceDecl)

      # From any interface type to Object.
      return true if to.ref.as(AST::TypeDecl).qualified_name == "java.lang.Object"

      # From any interface J to any interface K if J is a subinterface of K.
      return true if to.ref.is_a?(AST::InterfaceDecl) &&
                     to.ref.as(AST::InterfaceDecl).extends?(from.ref.as(AST::InterfaceDecl))
    end

    if from.is_object? && to.is_object?
      # From any class S to an interface K, if the class S implements the
      # interface K.
      return true if from.ref.is_a?(AST::ClassDecl) && to.ref.is_a?(AST::InterfaceDecl) &&
                     from.ref.as(AST::ClassDecl).implements?(to.ref.as(AST::InterfaceDecl))

      # From any class S to another class T, if S is a subclass of T.
      # (Special case to Object).
      return true if from.ref.is_a?(AST::ClassDecl) && to.ref.is_a?(AST::ClassDecl) &&
                     from.ref.as(AST::ClassDecl).extends?(to.ref.as(AST::ClassDecl))
    end

    return false
  end

  class Type
    property typ : Types
    property! ref : AST::TypeDecl
    property is_array : Bool = false

    def initialize(@typ : Types)
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
      raise Exception.new("you cannot do this. use is_object? instead") if s == Types::REFERENCE
      return self == Typing::Type.new(s)
    end

    def is_primitive? : Bool
      return PRIMITIVES.includes?(typ)
    end

    def is_object? : Bool
      return typ == Types::REFERENCE
    end

    def is_static? : Bool
      return typ == Types::STATIC
    end

    def ==(other) : Bool
      # When not comparing Types, always false.
      return false if !other.is_a?(Type)
      # When both are reference types and the same.
      return true if other.typ == self.typ && self.typ == Types::REFERENCE && other.ref.qualified_name == self.ref.qualified_name
      # When both are the same primative types (i.e. non-reference)
      return true if other.typ == self.typ
      # When both are numerical types.
      numbers = [Types::INT, Types::SHORT, Types::BYTE, Types::CHAR, Types::NUM]
      return true if numbers.includes?(other.typ) && numbers.includes?(self.typ)
      return false
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
        # `(Type | Nil)`.
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
    @file.ast.accept(TypeResolutionVisitor.new(@file.import_namespace))
    @file.ast.accept(StmtTypeCheckVisitor.new(@file.import_namespace))
  end
end

# `TypeResolutionVisitor` resolves all expression types. If there is a
# type issues, an exception is raised by an AST's `resolve_type` method.
class TypeResolutionVisitor < Visitor::GenericVisitor
  def initialize(@namespace : ImportNamespace)
  end

  def visit(node : AST::ClassDecl)
    @namespace.current_class = node
  end

  def visit(node : AST::ConstInteger | AST::ConstBool | AST::ConstChar | AST::ConstString) : Nil
    node.get_type(@namespace)
    super
  end

  def visit(node : AST::ConstNull) : Nil
    node.get_type(@namespace)
    super
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
    if node.expr? && node.expr.get_type(@namespace).is_type?(Typing::Types::BOOLEAN)
      raise TypeCheckStageError.new("for-loop comparison clause is not a bool, instead got: #{node.expr.get_type(@namespace)}")
    end
    super
  end

  def visit(node : AST::WhileStmt) : Nil
    if !node.expr.get_type(@namespace).is_type?(Typing::Types::BOOLEAN)
      raise TypeCheckStageError.new("while-loop comparison clause is not a bool, instead got: #{node.expr.get_type(@namespace).to_s}")
    end
    super
  end

  def visit(node : AST::DeclStmt) : Nil
    init_typ = node.var.init.get_type(@namespace)
    typ = node.typ.to_type
    unless Typing.can_convert_type(init_typ, typ)
      raise TypeCheckStageError.new("variable decl #{node.var.name} types wrong: expected {#{typ.to_s}} got #{node.var.init.get_type(@namespace).to_s}")
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
      raise TypeCheckStageError.new("method #{method_name} is returning #{return_typ.try &.to_s}, expected #{method_typ.try &.to_s}") unless Typing.can_convert_type(return_typ, method_typ)
    end
    super
  end
end
