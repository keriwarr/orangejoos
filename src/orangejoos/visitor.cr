
require "./ast.cr"
require "./compiler_errors.cr"

module Visitor
  abstract class Visitor
    @depth = 0

    abstract def visit(node : AST::PrimativeTyp) : Nil
    abstract def visit(node : AST::ClassTyp) : Nil
    abstract def visit(node : AST::Literal) : Nil
    abstract def visit(node : AST::Keyword) : Nil
    abstract def visit(node : AST::PackageDecl) : Nil
    abstract def visit(node : AST::ImportDecl) : Nil
    abstract def visit(node : AST::Modifier) : Nil
    abstract def visit(node : AST::ClassDecl) : Nil
    abstract def visit(node : AST::InterfaceDecl) : Nil
    abstract def visit(node : AST::SimpleName) : Nil
    abstract def visit(node : AST::QualifiedName) : Nil
    abstract def visit(node : AST::FieldDecl) : Nil
    abstract def visit(node : AST::File) : Nil
    abstract def visit(node : AST::Param) : Nil
    abstract def visit(node : AST::Block) : Nil
    abstract def visit(node : AST::ExprOp) : Nil
    abstract def visit(node : AST::ExprInstanceOf) : Nil
    abstract def visit(node : AST::ExprClassInit) : Nil
    abstract def visit(node : AST::ExprThis) : Nil
    abstract def visit(node : AST::ExprRef) : Nil
    abstract def visit(node : AST::ConstInteger) : Nil
    abstract def visit(node : AST::ConstBool) : Nil
    abstract def visit(node : AST::ConstChar) : Nil
    abstract def visit(node : AST::ConstString) : Nil
    abstract def visit(node : AST::ConstNull) : Nil
    abstract def visit(node : AST::VariableDecl) : Nil
    abstract def visit(node : AST::DeclStmt) : Nil
    abstract def visit(node : AST::ForStmt) : Nil
    abstract def visit(node : AST::WhileStmt) : Nil
    abstract def visit(node : AST::IfStmt) : Nil
    abstract def visit(node : AST::MethodInvoc) : Nil
    abstract def visit(node : AST::ExprArrayAccess) : Nil
    abstract def visit(node : AST::ExprArrayCreation) : Nil
    abstract def visit(node : AST::MethodDecl) : Nil
    abstract def visit(node : AST::ConstructorDecl) : Nil
    abstract def visit(node : AST::ReturnStmt) : Nil
    abstract def visit(node : AST::CastExpr) : Nil
    abstract def visit(node : AST::ParenExpr) : Nil
    abstract def visit(node : AST::Variable) : Nil

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
    def visit(node : AST::PrimitiveTyp) : Nil
    end

    def visit(node : AST::ClassTyp) : Nil
      node.name.accept(self)
    end

    def visit(node : AST::Literal) : Nil
    end

    def visit(node : AST::Keyword) : Nil
    end

    def visit(node : AST::PackageDecl) : Nil
      node.path.accept(self)
    end

    def visit(node : AST::ImportDecl) : Nil
      node.path.accept(self)
    end

    def visit(node : AST::Modifier) : Nil
      raise Exception.new("should not be executed")
    end

    def visit(node : AST::ClassDecl) : Nil
      node.interfaces.each { |i| i.accept(self) }
      node.body.each       { |b| b.accept(self) }
      node.super_class.accept(self) if node.super_class?
    rescue ex : CompilerError
      ex.register("class_name", node.name)
      raise ex
    end

    def visit(node : AST::InterfaceDecl) : Nil
      node.extensions.each { |i| i.accept(self) }
      node.body.each       { |b| b.accept(self) }
    rescue ex : CompilerError
      ex.register("interface_name", node.name)
      raise ex
    end

    def visit(node : AST::SimpleName) : Nil
    end

    def visit(node : AST::QualifiedName) : Nil
    end

    def visit(node : AST::FieldDecl) : Nil
      node.typ.accept(self)
      node.var.accept(self)
    rescue ex : CompilerError
      ex.register("field_name", node.var.name)
      raise ex
    end

    def visit(node : AST::File) : Nil
      node.package.accept(self) if node.package?
      node.imports.each { |i| i.accept(self) }
      node.decls.each   { |d| d.accept(self) }
    end

    def visit(node : AST::Param) : Nil
      node.typ.accept(self)
    end

    def visit(node : AST::Block) : Nil
      node.stmts.each { |s| s.accept(self) }
    end

    def visit(node : AST::ExprOp) : Nil
      node.operands.each { |o| o.accept(self) }
    end

    def visit(node : AST::ExprInstanceOf) : Nil
      node.lhs.accept(self)
      node.typ.accept(self)
    end

    def visit(node : AST::ExprClassInit) : Nil
      node.typ.accept(self)
      node.args.each { |a| a.accept(self) }
    end

    def visit(node : AST::ExprThis) : Nil
    end

    def visit(node : AST::ExprFieldAccess) : Nil
      node.obj.accept(self)
    end

    def visit(node : AST::ExprRef) : Nil
      node.name.accept(self)
    end

    def visit(node : AST::ConstInteger) : Nil
    end

    def visit(node : AST::ConstBool) : Nil
    end

    def visit(node : AST::ConstChar) : Nil
    end

    def visit(node : AST::ConstString) : Nil
    end

    def visit(node : AST::ConstNull) : Nil
    end

    def visit(node : AST::VariableDecl) : Nil
      node.init.accept(self) if node.init?
    end

    def visit(node : AST::DeclStmt) : Nil
      node.typ.accept(self)
      node.var.accept(self)
    end

    def visit(node : AST::ForStmt) : Nil
      node.init.accept(self) if node.init?
      node.expr.accept(self) if node.expr?
      node.update.accept(self) if node.update?
      node.body.accept(self)
    end

    def visit(node : AST::WhileStmt) : Nil
      node.expr.accept(self)
      node.body.accept(self)
    end

    def visit(node : AST::IfStmt) : Nil
      node.expr.accept(self)
      node.if_body.accept(self)
      node.else_body.accept(self) if node.else_body?
    end

    def visit(node : AST::MethodInvoc) : Nil
      node.expr.accept(self)
      node.args.each      { |b| b.accept(self) }
    end

    def visit(node : AST::ExprArrayAccess) : Nil
      node.expr.accept(self)
      node.index.accept(self)
    end

    def visit(node : AST::ExprArrayCreation) : Nil
      node.arr.accept(self)
      node.dim.accept(self)
    end

    def visit(node : AST::MethodDecl) : Nil
      node.typ.accept(self) if node.typ?
      node.params.each    { |p| p.accept(self) }
      node.body.each      { |b| b.accept(self) } if node.body?
    rescue ex : CompilerError
      ex.register("method", node.name)
      raise ex
    end

    def visit(node : AST::ConstructorDecl) : Nil
      node.name.accept(self)
      node.params.each    { |p| p.accept(self) }
      node.body.each      { |b| b.accept(self) }
    end

    def visit(node : AST::ReturnStmt) : Nil
      node.expr.accept(self) if node.expr?
    end

    def visit(node : AST::CastExpr) : Nil
      node.rhs.accept(self)
      node.typ.accept(self)
    end

    def visit(node : AST::ParenExpr) : Nil
      node.expr.accept(self)
    end

    def visit(node : AST::Variable) : Nil
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
