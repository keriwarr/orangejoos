
require "./ast.cr"

module Visitor
  abstract class Visitor
    abstract def visit(node : AST::PrimativeTyp) : Nil
    abstract def visit(node : AST::ReferenceTyp) : Nil
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
    abstract def visit(node : AST::MethodDecl) : Nil
    abstract def visit(node : AST::ConstructorDecl) : Nil
  end

  class GenericVisitor < Visitor
    def visit(node : AST::PrimitiveTyp) : Nil
    end

    def visit(node : AST::ReferenceTyp) : Nil
      # TODO(keri): why doesn't this work??
      # referenceTypNode.name.accept(self)
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
    end

    def visit(node : AST::ClassDecl) : Nil
      node.modifiers.each  { |m| m.accept(self) }
      node.interfaces.each { |i| i.accept(self) }
      node.body.each       { |b| b.accept(self) }
      node.super_class.accept(self) if node.super_class?
    end

    def visit(node : AST::InterfaceDecl) : Nil
      node.modifiers.each  { |m| m.accept(self) }
      node.extensions.each { |i| i.accept(self) }
      node.body.each       { |b| b.accept(self) }
    end

    def visit(node : AST::SimpleName) : Nil
    end

    def visit(node : AST::QualifiedName) : Nil
    end

    def visit(node : AST::FieldDecl) : Nil
      node.modifiers.each { |m| m.accept(self) }
      node.typ.accept(self)
      node.decl.accept(self)
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

    def visit(node : AST::ExprClassInit) : Nil
      node.name.accept(self)
      node.args.each { |a| a.accept(self) }
    end

    def visit(node : AST::ExprThis) : Nil
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

    def visit(node : AST::MethodDecl) : Nil
      node.typ.accept(self)
      node.modifiers.each { |m| m.accept(self) }
      node.params.each    { |p| p.accept(self) }
      node.body.each      { |b| b.accept(self) } if node.body?
    end

    def visit(node : AST::ConstructorDecl) : Nil
      node.name.accept(self)
      node.modifiers.each { |m| m.accept(self) }
      node.params.each    { |p| p.accept(self) }
      node.body.each      { |b| b.accept(self) }
    end
  end

  class ValueRangeVisitor < GenericVisitor
    def visit(node : AST::ConstInteger) : Nil
      puts "I found an integer! #{node.val}"
      super
    end
  end
end
