module Typing
  class Type
    def initialize(@name : String)
    end

    def undo_array_type : Type
      raise Exception.new("undo_array_type not implemented")
    end

    def is_type?(s : String)
      if s == "num"
        # TODO(joey): Check all types of integers.
        return ["num"].includes?(@name)
      end
      return s == @name
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
        # the user forgets to return, it accidentally becomes `(Type |
        # Nil)`.
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
    @file.ast = @file.ast.accept(TypeResolutionVisitor.new)
    @file.ast = @file.ast.accept(StmtTypeCheckVisitor.new)
  end
end

# `TypeResolutionVisitor` resolves all expression types. If there is a
# type-mismatch, an exception is raised.
class TypeResolutionVisitor < Visitor::GenericVisitor
  def initialize
  end

  def visit(node : AST::ConstInteger | AST::ConstBool | AST::ConstChar | AST::ConstString) : AST::Node
    node.get_type()
    return super
  end

  def visit(node : AST::ConstNull) : AST::Node
    node.get_type()
    return super
  end

  # abstract def visit(node : AST::PrimativeTyp) : AST::Node
  # abstract def visit(node : AST::ReferenceTyp) : AST::Node
  # abstract def visit(node : AST::Literal) : AST::Node
  # abstract def visit(node : AST::Keyword) : AST::Node
  # abstract def visit(node : AST::PackageDecl) : AST::Node
  # abstract def visit(node : AST::ImportDecl) : AST::Node
  # abstract def visit(node : AST::Modifier) : AST::Node
  # abstract def visit(node : AST::ClassDecl) : AST::Node
  # abstract def visit(node : AST::InterfaceDecl) : AST::Node
  # abstract def visit(node : AST::SimpleName) : AST::Node
  # abstract def visit(node : AST::QualifiedName) : AST::Node
  # abstract def visit(node : AST::FieldDecl) : AST::Node
  # abstract def visit(node : AST::File) : AST::Node
  # abstract def visit(node : AST::Param) : AST::Node
  # abstract def visit(node : AST::Block) : AST::Node
  # abstract def visit(node : AST::ExprOp) : AST::Node
  # abstract def visit(node : AST::ExprClassInit) : AST::Node
  # abstract def visit(node : AST::ExprThis) : AST::Node
  # abstract def visit(node : AST::ExprRef) : AST::Node
  # abstract def visit(node : AST::ConstInteger) : AST::Node
  # abstract def visit(node : AST::ConstBool) : AST::Node
  # abstract def visit(node : AST::ConstChar) : AST::Node
  # abstract def visit(node : AST::ConstString) : AST::Node
  # abstract def visit(node : AST::ConstNull) : AST::Node
  # abstract def visit(node : AST::VariableDecl) : AST::Node
  # abstract def visit(node : AST::DeclStmt) : AST::Node
  # abstract def visit(node : AST::ForStmt) : AST::Node
  # abstract def visit(node : AST::WhileStmt) : AST::Node
  # abstract def visit(node : AST::IfStmt) : AST::Node
  # abstract def visit(node : AST::MethodInvoc) : AST::Node
  # abstract def visit(node : AST::ExprArrayAccess) : AST::Node
  # abstract def visit(node : AST::ExprArrayCreation) : AST::Node
  # abstract def visit(node : AST::MethodDecl) : AST::Node
  # abstract def visit(node : AST::ConstructorDecl) : AST::Node
  # abstract def visit(node : AST::ReturnStmt) : AST::Node
  # abstract def visit(node : AST::CastExpr) : AST::Node
  # abstract def visit(node : AST::ParenExpr) : AST::Node
  # abstract def visit(node : AST::Variable) : AST::Node
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

  def visit(node : AST::ForStmt) : AST::Node
    if node.expr? && node.expr.get_type().is_type?("bool")
      raise TypeCheckStageError.new("for-loop comparison clause is not a bool, instead got: #{node.expr.get_type()}")
    end
    return super
  end

  def visit(node : AST::WhileStmt) : AST::Node
    if !node.expr.get_type().is_type?("bool")
      raise TypeCheckStageError.new("while-loop comparison clause is not a bool, instead got: #{node.expr.get_type().to_s}")
    end
    return super
  end

end
