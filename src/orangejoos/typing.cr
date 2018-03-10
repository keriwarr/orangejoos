module Typing
  class Type
    property name : String

    def initialize(@name : String)
    end

    def undo_array_type : Type
      raise Exception.new("undo_array_type not implemented")
    end

    def is_type?(s : String)
      return self == Typing::Type.new(s)
    end

    def ==(other)
      if other.is_a?(Type)
        return true if other.name == self.name
        numbers = ["int", "num", "byte", "short"]
        return true if numbers.includes?(other.name) && numbers.includes?(self.name)
      end
      return false
    end

    def to_s : String
      return "<Type \"#{@name}\">"
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
    if node.expr? && node.expr.get_type().is_type?("boolean")
      raise TypeCheckStageError.new("for-loop comparison clause is not a bool, instead got: #{node.expr.get_type()}")
    end
    super
  end

  def visit(node : AST::WhileStmt) : Nil
    if !node.expr.get_type().is_type?("boolean")
      raise TypeCheckStageError.new("while-loop comparison clause is not a bool, instead got: #{node.expr.get_type().to_s}")
    end
    super
  end

  def visit(node : AST::DeclStmt) : Nil
    if node.var.init.get_type() != Typing::Type.new(node.typ.name_str)
      raise TypeCheckStageError.new("variable decl #{node.var.name} types wrong: expected #{node.typ.name_str} got #{node.var.init.get_type().to_s}")
    end
    super
  end

end
