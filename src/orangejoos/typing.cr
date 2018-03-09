module Typing
  class Type
    def initialize(@name : String)
    end
  end

  module Typed
    property! _typ : Type

    def get_type : Type
      if self._typ?
        return self._typ
      end
      self._typ = self.resolve_type
      return self._typ
    end

    abstract def resolve_type() : Type
  end
end

class TypeCheck
  def initialize(@file : SourceFile, @verbose : Bool)
  end

  def check
    @file.ast = @file.ast.accept(TypeResolutionVisitor.new)
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
    if node.expr? && node.expr.get_type() != "bool"
      raise TypeCheckStageError.new("for loop comparison is not a bool, instead: #{node.expr.get_type()}")
    end
    return super
  end

  def visit(node : AST::WhileStmt) : AST::Node
    if node.expr? && node.expr.get_type() != "bool"
      raise TypeCheckStageError.new("while update is not a bool, instead: #{node.expr.get_type()}")
    end
    return super
  end

end
