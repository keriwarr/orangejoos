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
    property! reference_name : String
    property is_array : Bool = false

    def initialize(@typ : Types)
    end

    def initialize(@typ : Types, @is_array : Bool)
    end

    def initialize(@typ : Types, @reference_name : String)
    end

    def initialize(@typ : Types, @reference_name : String, @is_array : Bool)
    end

    def from_array_type : Type
      raise Exception.new("cannot dereference non-array type") if !is_array
      return Type.new(typ, reference_name, false) if reference_name?
      return Type.new(typ, false)
    end

    def to_array_type : Type
      raise Exception.new("cannot nest array type") if is_array
      return Type.new(typ, reference_name, true) if reference_name?
      return Type.new(typ, true)
    end

    def is_type?(s : Types)
      return self == Typing::Type.new(s)
    end

    def ==(other)
      # When not comparing Types, always false.
      return false if !other.is_a?(Type)
      # When both are reference types and the same.
      return true if other.typ == self.typ && self.typ == Types::REFERENCE && other.reference_name == self.reference_name
      # When both are the same primative types (i.e. non-reference)
      return true if other.typ == self.typ
      # When both are numerical types.
      numbers = [Types::INT, Types::SHORT, Types::BYTE, Types::NUM]
      return true if numbers.includes?(other.typ) && numbers.includes?(self.typ)
    end

    def to_s : String
      return "<Type \"#{typ} #{reference_name?} #{is_array} \">"
    end
  end

  module Typed
    property! evaluated_typ : Type

    def get_type : Type
      if !evaluated_typ?
        # This is done to assert `resolve_type` signature is (Type). If
        # the user forgets to return, it accidentally becomes
        # `(Type | Nil)`.
        typ : Type = resolve_type()
        evaluated_typ = typ
      end
      return evaluated_typ.not_nil!
    end

    abstract def resolve_type : Type
  end
end

class TypeCheck
  def initialize(@file : SourceFile, @verbose : Bool)
  end

  def check
    @file.ast.accept(TypeResolutionVisitor.new)
    @file.ast.accept(StmtTypeCheckVisitor.new)
  end
end

# `TypeResolutionVisitor` resolves all expression types. If there is a
# type issues, an exception is raised by an AST's `resolve_type` method.
class TypeResolutionVisitor < Visitor::GenericVisitor
  def initialize
  end

  def visit(node : AST::ConstInteger | AST::ConstBool | AST::ConstChar | AST::ConstString) : Nil
    node.get_type()
    super
  end

  def visit(node : AST::ConstNull) : Nil
    node.get_type()
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
  def initialize
  end

  def visit(node : AST::ForStmt) : Nil
    if node.expr? && node.expr.get_type().is_type?(Typing::Types::BOOLEAN)
      raise TypeCheckStageError.new("for-loop comparison clause is not a bool, instead got: #{node.expr.get_type()}")
    end
    super
  end

  def visit(node : AST::WhileStmt) : Nil
    if !node.expr.get_type().is_type?(Typing::Types::BOOLEAN)
      raise TypeCheckStageError.new("while-loop comparison clause is not a bool, instead got: #{node.expr.get_type().to_s}")
    end
    super
  end

  def visit(node : AST::DeclStmt) : Nil
    if node.var.init.get_type() != node.typ.get_type()
      raise TypeCheckStageError.new("variable decl #{node.var.name} types wrong: expected #{node.typ.name_str} got #{node.var.init.get_type().to_s}")
    end
    super
  end

end
