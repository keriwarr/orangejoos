
require "./ast.cr"
require "./compiler_errors.cr"

module Visitor
  abstract class Visitor
    @depth = 0

    abstract def visit(node : AST::PrimativeTyp)
    abstract def visit(node : AST::ReferenceTyp)
    abstract def visit(node : AST::Literal)
    abstract def visit(node : AST::Keyword)
    abstract def visit(node : AST::PackageDecl)
    abstract def visit(node : AST::ImportDecl)
    abstract def visit(node : AST::Modifier)
    abstract def visit(node : AST::ClassDecl)
    abstract def visit(node : AST::InterfaceDecl)
    abstract def visit(node : AST::SimpleName)
    abstract def visit(node : AST::QualifiedName)
    abstract def visit(node : AST::FieldDecl)
    abstract def visit(node : AST::File)
    abstract def visit(node : AST::Param)
    abstract def visit(node : AST::Block)
    abstract def visit(node : AST::ExprOp)
    abstract def visit(node : AST::ExprClassInit)
    abstract def visit(node : AST::ExprThis)
    abstract def visit(node : AST::ExprRef)
    abstract def visit(node : AST::ConstInteger)
    abstract def visit(node : AST::ConstBool)
    abstract def visit(node : AST::ConstChar)
    abstract def visit(node : AST::ConstString)
    abstract def visit(node : AST::ConstNull)
    abstract def visit(node : AST::VariableDecl)
    abstract def visit(node : AST::DeclStmt)
    abstract def visit(node : AST::ForStmt)
    abstract def visit(node : AST::WhileStmt)
    abstract def visit(node : AST::IfStmt)
    abstract def visit(node : AST::MethodInvoc)
    abstract def visit(node : AST::ExprArrayAccess)
    abstract def visit(node : AST::ExprArrayCreation)
    abstract def visit(node : AST::MethodDecl)
    abstract def visit(node : AST::ConstructorDecl)
    abstract def visit(node : AST::ReturnStmt)
    abstract def visit(node : AST::CastExpr)
    abstract def visit(node : AST::ParenExpr)
    abstract def visit(node : AST::Variable)

    def descend
      @depth += 1
    end

    def ascend
      @depth -= 1

      if @depth == 0
        on_completion()
      end
    end

    def on_completion
    end
  end

  class GenericVisitor < Visitor
    def visit(node : AST::PrimitiveTyp)
    end

    def visit(node : AST::ReferenceTyp)
      node.name.accept(self)
    end

    def visit(node : AST::Literal)
    end

    def visit(node : AST::Keyword)
    end

    def visit(node : AST::PackageDecl)
      node.path.accept(self)
    end

    def visit(node : AST::ImportDecl)
      node.path.accept(self)
    end

    def visit(node : AST::Modifier)
      raise Exception.new("should not be executed")
    end

    def visit(node : AST::ClassDecl)
      node.interfaces.each { |i| i.accept(self) }
      node.body.each       { |b| b.accept(self) }
      node.super_class.accept(self) if node.super_class?
    end

    def visit(node : AST::InterfaceDecl)
      node.extensions.each { |i| i.accept(self) }
      node.body.each       { |b| b.accept(self) }
    end

    def visit(node : AST::SimpleName)
    end

    def visit(node : AST::QualifiedName)
    end

    def visit(node : AST::FieldDecl)
      node.typ.accept(self)
      node.decl.accept(self)
    end

    def visit(node : AST::File)
      node.package.accept(self) if node.package?
      node.imports.each { |i| i.accept(self) }
      node.decls.each   { |d| d.accept(self) }
    end

    def visit(node : AST::Param)
      node.typ.accept(self)
    end

    def visit(node : AST::Block)
      node.stmts.each { |s| s.accept(self) }
    end

    def visit(node : AST::ExprOp)
      node.operands.each { |o| o.accept(self) }
    end

    def visit(node : AST::ExprClassInit)
      node.name.accept(self)
      node.args.each { |a| a.accept(self) }
    end

    def visit(node : AST::ExprThis)
    end

    def visit(node : AST::ExprFieldAccess)
      node.obj.accept(self)
    end

    def visit(node : AST::ExprRef)
      node.name.accept(self)
    end

    def visit(node : AST::ConstInteger)
    end

    def visit(node : AST::ConstBool)
    end

    def visit(node : AST::ConstChar)
    end

    def visit(node : AST::ConstString)
    end

    def visit(node : AST::ConstNull)
    end

    def visit(node : AST::VariableDecl)
      node.init.accept(self) if node.init?
    end

    def visit(node : AST::DeclStmt)
      node.typ.accept(self)
      node.var.accept(self)
    end

    def visit(node : AST::ForStmt)
      node.init.accept(self) if node.init?
      node.expr.accept(self) if node.expr?
      node.update.accept(self) if node.update?
      node.body.accept(self)
    end

    def visit(node : AST::WhileStmt)
      node.expr.accept(self)
      node.body.accept(self)
    end

    def visit(node : AST::IfStmt)
      node.expr.accept(self)
      node.if_body.accept(self)
      node.else_body.accept(self) if node.else_body?
    end

    def visit(node : AST::MethodInvoc)
      node.expr.accept(self) if node.expr?
      node.args.each      { |b| b.accept(self) }
    end

    def visit(node : AST::ExprArrayAccess)
      node.arr_expr.accept(self) if node.arr_expr?
      node.index.accept(self)
    end

    def visit(node : AST::ExprArrayCreation)
      # FIXME(joey): Not added due to the type specificity problem.
      # node.arr.accept(self)
      node.dim.accept(self)
    end

    def visit(node : AST::MethodDecl)
      node.typ.accept(self)
      node.params.each    { |p| p.accept(self) }
      node.body.each      { |b| b.accept(self) } if node.body?
    end

    def visit(node : AST::ConstructorDecl)
      node.name.accept(self)
      node.params.each    { |p| p.accept(self) }
      node.body.each      { |b| b.accept(self) }
    end

    def visit(node : AST::ReturnStmt)
      node.expr.accept(self) if node.expr?
    end

    def visit(node : AST::CastExpr)
      node.rhs.accept(self)
    end

    def visit(node : AST::ParenExpr)
      node.expr.accept(self)
    end

    def visit(node : AST::Variable)
      if node.name?
        node.name.accept(self)
      end
      if node.array_access?
        node.array_access.accept(self)
      end
      if node.field_access?
        node.field_access.accept(self)
      end
    end
  end
end
