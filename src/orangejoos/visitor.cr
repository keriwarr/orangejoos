
require "./ast.cr"
require "./compiler_errors.cr"

module Visitor
  abstract class Visitor
    abstract def visit(node : AST::PrimativeTyp) : AST::Node
    abstract def visit(node : AST::ReferenceTyp) : AST::Node
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
    abstract def visit(node : AST::MethodDecl) : AST::Node
    abstract def visit(node : AST::ConstructorDecl) : AST::Node

    abstract def descend()
    abstract def ascend()
    abstract def on_completion()
  end

  class GenericVisitor < Visitor
    @depth = 0

    def visit(node : AST::PrimitiveTyp) : AST::Node
      return node
    end

    def visit(node : AST::ReferenceTyp) : AST::Node
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
      return node
    end

    def visit(node : AST::ClassDecl) : AST::Node
      node.modifiers.map!  { |m| m.accept(self) }
      node.interfaces.map! { |i| i.accept(self) }
      node.body.map!       { |b| b.accept(self) }
      node.super_class = node.super_class.accept(self) if node.super_class?
      return node
    end

    def visit(node : AST::InterfaceDecl) : AST::Node
      node.modifiers.map!  { |m| m.accept(self) }
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
      node.modifiers.map! { |m| m.accept(self) }
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

    def visit(node : AST::ExprClassInit) : AST::Node
      node.name = node.name.accept(self)
      node.args.map! { |a| a.accept(self) }
      return node
    end

    def visit(node : AST::ExprThis) : AST::Node
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

    def visit(node : AST::MethodDecl) : AST::Node
      node.typ = node.typ.accept(self)
      node.modifiers.map! { |m| m.accept(self) }
      node.params.map!    { |p| p.accept(self) }
      node.body.map!      { |b| b.accept(self) } if node.body?
      return node
    end

    def visit(node : AST::ConstructorDecl) : AST::Node
      node.name = node.name.accept(self)
      node.modifiers.map! { |m| m.accept(self) }
      node.params.map!    { |p| p.accept(self) }
      node.body.map!      { |b| b.accept(self) }
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
