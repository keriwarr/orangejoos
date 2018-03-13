module Visitor
  abstract class MutatingVisitor
    abstract def visit(node : AST::PrimativeTyp) : AST::Node
    abstract def visit(node : AST::ClassTyp) : AST::Node
    abstract def visit(node : AST::Literal) : AST::Node
    abstract def visit(node : AST::Keyword) : AST::Node
    abstract def visit(node : AST::PackageDecl) : AST::Node
    abstract def visit(node : AST::ImportDecl) : AST::Node
    abstract def visit(node : AST::Modifier) : AST::Node
    abstract def visit(node : AST::ClassDecl) : AST::Node
    abstract def visit(node : AST::InterfaceDecl) : AST::Node
    abstract def visit(node : AST::SimpleName) : AST::Node
    abstract def visit(node : AST::QualifiedName) : AST::Node
    abstract def visit(node : AST::FieldDecl) : AST::Node
    abstract def visit(node : AST::File) : AST::Node
    abstract def visit(node : AST::Param) : AST::Node
    abstract def visit(node : AST::Block) : AST::Node
    abstract def visit(node : AST::ExprOp) : AST::Node
    abstract def visit(node : AST::ExprInstanceOf) : Nil
    abstract def visit(node : AST::ExprClassInit) : AST::Node
    abstract def visit(node : AST::ExprThis) : AST::Node
    abstract def visit(node : AST::ExprRef) : AST::Node
    abstract def visit(node : AST::ConstInteger) : AST::Node
    abstract def visit(node : AST::ConstBool) : AST::Node
    abstract def visit(node : AST::ConstChar) : AST::Node
    abstract def visit(node : AST::ConstString) : AST::Node
    abstract def visit(node : AST::ConstNull) : AST::Node
    abstract def visit(node : AST::VariableDecl) : AST::Node
    abstract def visit(node : AST::DeclStmt) : AST::Node
    abstract def visit(node : AST::ForStmt) : AST::Node
    abstract def visit(node : AST::WhileStmt) : AST::Node
    abstract def visit(node : AST::IfStmt) : AST::Node
    abstract def visit(node : AST::MethodInvoc) : AST::Node
    abstract def visit(node : AST::ExprArrayAccess) : AST::Node
    abstract def visit(node : AST::ExprArrayCreation) : AST::Node
    abstract def visit(node : AST::MethodDecl) : AST::Node
    abstract def visit(node : AST::ConstructorDecl) : AST::Node
    abstract def visit(node : AST::ReturnStmt) : AST::Node
    abstract def visit(node : AST::CastExpr) : AST::Node
    abstract def visit(node : AST::ParenExpr) : AST::Node
    abstract def visit(node : AST::Variable) : AST::Node

    abstract def descend()
    abstract def ascend()
    abstract def on_completion()
  end

  class GenericMutatingVisitor < MutatingVisitor
    @depth = 0

    def visit(node : AST::PrimitiveTyp) : AST::Node
      return node
    end

    def visit(node : AST::ClassTyp) : AST::Node
      node.name = node.name.accept(self)
      return node
    end

    def visit(node : AST::Literal) : AST::Node
      return node
    end

    def visit(node : AST::Keyword) : AST::Node
      return node
    end

    def visit(node : AST::PackageDecl) : AST::Node
      node.path = node.path.accept(self)
      return node
    end

    def visit(node : AST::ImportDecl) : AST::Node
      node.path = node.path.accept(self)
      return node
    end

    def visit(node : AST::Modifier) : AST::Node
      raise Exception.new("should not be executed")
      return node
    end

    def visit(node : AST::ClassDecl) : AST::Node
      node.interfaces.map! { |i| i.accept(self) }
      node.body.map!       { |b| b.accept(self) }
      node.super_class = node.super_class.accept(self) if node.super_class?
      return node
    end

    def visit(node : AST::InterfaceDecl) : AST::Node
      node.extensions.map! { |i| i.accept(self) }
      node.body.map!       { |b| b.accept(self) }
      return node
    end

    def visit(node : AST::SimpleName) : AST::Node
      return node
    end

    def visit(node : AST::QualifiedName) : AST::Node
      return node
    end

    def visit(node : AST::FieldDecl) : AST::Node
      node.typ = node.typ.accept(self)
      node.decl = node.decl.accept(self)
      return node
    end

    def visit(node : AST::File) : AST::Node
      node.package = node.package.accept(self) if node.package?
      node.imports.map! { |i| i.accept(self) }
      node.decls.map!   { |d| d.accept(self) }
      return node
    end

    def visit(node : AST::Param) : AST::Node
      node.typ = node.typ.accept(self)
      return node
    end

    def visit(node : AST::Block) : AST::Node
      node.stmts.map! { |s| s.accept(self) }
      return node
    end

    def visit(node : AST::ExprOp) : AST::Node
      node.operands.map! { |o| o.accept(self) }
      return node
    end

    def visit(node : AST::ExprInstanceOf) : AST::Node
      node.lhs = node.lhs.accept(self)
      node.typ = node.typ.accept(self)
      return node
    end

    def visit(node : AST::ExprClassInit) : AST::Node
      node.name = node.name.accept(self)
      node.args.map! { |a| a.accept(self) }
      return node
    end

    def visit(node : AST::ExprThis) : AST::Node
      return node
    end

    def visit(node : AST::ExprFieldAccess) : AST::Node
      node.obj = node.obj.accept(self)
      return node
    end

    def visit(node : AST::ExprRef) : AST::Node
      node.name = node.name.accept(self)
      return node
    end

    def visit(node : AST::ConstInteger) : AST::Node
      return node
    end

    def visit(node : AST::ConstBool) : AST::Node
      return node
    end

    def visit(node : AST::ConstChar) : AST::Node
      return node
    end

    def visit(node : AST::ConstString) : AST::Node
      return node
    end

    def visit(node : AST::ConstNull) : AST::Node
      return node
    end

    def visit(node : AST::VariableDecl) : AST::Node
      node.init = node.init.accept(self) if node.init?
      return node
    end

    def visit(node : AST::DeclStmt) : AST::Node
      node.typ = node.typ.accept(self)
      node.var = node.var.accept(self)
      return node
    end

    def visit(node : AST::ForStmt) : AST::Node
      node.init = node.init.accept(self) if node.init?
      node.expr = node.expr.accept(self) if node.expr?
      node.update = node.update.accept(self) if node.update?
      node.body = node.body.accept(self)
      return node
    end

    def visit(node : AST::WhileStmt) : AST::Node
      node.expr = node.expr.accept(self)
      node.body = node.body.accept(self)
      return node
    end

    def visit(node : AST::IfStmt) : AST::Node
      node.expr = node.expr.accept(self)
      node.if_body = node.if_body.accept(self)
      node.else_body = node.else_body.accept(self) if node.else_body?
      return node
    end

    def visit(node : AST::MethodInvoc) : AST::Node
      node.expr = node.expr.accept(self) if node.expr?
      node.args.map!      { |b| b.accept(self) }
      return node
    end

    def visit(node : AST::ExprArrayAccess) : AST::Node
      node.arr_expr = node.arr_expr.accept(self) if node.arr_expr?
      node.index = node.index.accept(self)
      return node
    end

    def visit(node : AST::ExprArrayCreation) : AST::Node
      # FIXME(joey): Not added due to the type specificity problem.
      # node.arr = node.arr.accept(self)
      node.dim = node.dim.accept(self)
      return node
    end

    def visit(node : AST::MethodDecl) : AST::Node
      node.typ = node.typ.accept(self)
      node.params.map!    { |p| p.accept(self) }
      node.body.map!      { |b| b.accept(self) } if node.body?
      return node
    end

    def visit(node : AST::ConstructorDecl) : AST::Node
      node.name = node.name.accept(self)
      node.params.map!    { |p| p.accept(self) }
      node.body.map!      { |b| b.accept(self) }
      return node
    end

    def visit(node : AST::ReturnStmt) : AST::Node
      node.expr = node.expr.accept(self) if node.expr?
      return node
    end

    def visit(node : AST::CastExpr) : AST::Node
      node.rhs = node.rhs.accept(self)
      return node
    end

    def visit(node : AST::ParenExpr) : AST::Node
      node.expr = node.expr.accept(self)
      return node
    end

    def visit(node : AST::Variable) : AST::Node
      if node.name?
        node.name = node.name.accept(self)
      end
      if node.array_access?
        node.array_access = node.array_access.accept(self)
      end
      if node.field_access?
        node.field_access = node.field_access.accept(self)
      end
      return node
    end

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
end
