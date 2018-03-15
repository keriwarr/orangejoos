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

    # FIXME(joey): Remove usage.
    TODO
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

    def is_type?(s : Types)
      return self == Typing::Type.new(s)
    end

    def is_object?
      return typ == Types::REFERENCE
    end

    def ==(other)
      # When not comparing Types, always false.
      return false if !other.is_a?(Type)
      # When both are reference types and the same.
      return true if other.typ == self.typ && self.typ == Types::REFERENCE && other.ref.qualified_name == self.ref.qualified_name
      # When both are the same primative types (i.e. non-reference)
      return true if other.typ == self.typ
      # When both are numerical types.
      numbers = [Types::INT, Types::SHORT, Types::BYTE, Types::NUM]
      return true if numbers.includes?(other.typ) && numbers.includes?(self.typ)
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
    # FIXME(joey): Currently this check is not done, because the stdlib
    # does a standard type cast.
    # @file.ast.accept(InvalidCastExpressionVisitor.new)
    @file.ast.accept(TypeResolutionVisitor.new(@file.import_namespace))
    @file.ast.accept(StmtTypeCheckVisitor.new(@file.import_namespace))
  end
end

# `TypeResolutionVisitor` resolves all expression types. If there is a
# type issues, an exception is raised by an AST's `resolve_type` method.
class TypeResolutionVisitor < Visitor::GenericVisitor
  def initialize(@namespace : ImportNamespace)
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
    unless typ == init_typ || (typ.is_object? && init_typ.is_type?(Typing::Types::NULL)) || (typ.is_array && init_typ.is_type?(Typing::Types::NULL))
      raise TypeCheckStageError.new("variable decl #{node.var.name} types wrong: expected {#{typ.to_s}} got #{node.var.init.get_type(@namespace).to_s}")
    end
    super
  end

end

# `InvalidCastExpressionVisitor` checks if any casts are to an invalid
# type, i.e. not a ClassType.
class InvalidCastExpressionVisitor < Visitor::GenericVisitor
  def visit(node : AST::CastExpr) : Nil
    typ_node = node.typ
    return if typ_node.is_a?(AST::ClassTyp)

    if typ_node.cardinality == 0
      raise TypeCheckStageError.new("cannot cast to a #{typ_node.pprint}, not a ReferenceType")
    end
  end
end
