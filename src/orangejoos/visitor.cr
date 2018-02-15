
require "./ast.cr"

module Visitor

  abstract class Visitor
    abstract def visit(primativeTypNode : AST::PrimativeTyp) : Nil
    abstract def visit(referenceTypNode : AST::ReferenceTyp) : Nil
    abstract def visit(literalNode : AST::Literal) : Nil
    abstract def visit(keywordNode : AST::Keyword) : Nil
    abstract def visit(packageDeclNode : AST::PackageDecl) : Nil
    abstract def visit(importDeclNode : AST::ImportDecl) : Nil
    abstract def visit(modifierNode : AST::Modifier) : Nil
    abstract def visit(classDeclNode : AST::ClassDecl) : Nil
    abstract def visit(interfaceDeclNode : AST::InterfaceDecl) : Nil
    abstract def visit(simpleNameNode : AST::SimpleName) : Nil
    abstract def visit(qualifiedNameNode : AST::QualifiedName) : Nil
    abstract def visit(fieldDeclNode : AST::FieldDecl) : Nil
    abstract def visit(fileNode : AST::File) : Nil
    abstract def visit(paramNode : AST::Param) : Nil
    abstract def visit(blockNode : AST::Block) : Nil
    abstract def visit(exprOpNode : AST::ExprOp) : Nil
    abstract def visit(exprClassInitNode : AST::ExprClassInit) : Nil
    abstract def visit(exprThisNode : AST::ExprThis) : Nil
    abstract def visit(exprRefNode : AST::ExprRef) : Nil
    abstract def visit(constIntegerNode : AST::ConstInteger) : Nil
    abstract def visit(constBoolNode : AST::ConstBool) : Nil
    abstract def visit(constCharNode : AST::ConstChar) : Nil
    abstract def visit(constStringNode : AST::ConstString) : Nil
    abstract def visit(constNullNode : AST::ConstNull) : Nil
    abstract def visit(variableDeclNode : AST::VariableDecl) : Nil
    abstract def visit(declStmtNode : AST::DeclStmt) : Nil
    abstract def visit(methodDeclNode : AST::MethodDecl) : Nil
    abstract def visit(constructorDeclNode : AST::ConstructorDecl) : Nil
  end

  class GenericVisitor < Visitor
    def visit(primativeTypNode : AST::PrimativeTyp) : Nil
    end

    def visit(referenceTypNode : AST::ReferenceTyp) : Nil
      # TODO(keri): why doesn't this work??
      # referenceTypNode.name.accept(self)
    end

    def visit(literalNode : AST::Literal) : Nil
    end

    def visit(keywordNode : AST::Keyword) : Nil
    end

    def visit(packageDeclNode : AST::PackageDecl) : Nil
      packageDeclNode.path.accept(self)
    end

    def visit(importDeclNode : AST::ImportDecl) : Nil
      importDeclNode.path.accept(self)
    end

    def visit(modifierNode : AST::Modifier) : Nil
    end

    def visit(classDeclNode : AST::ClassDecl) : Nil
      classDeclNode.modifiers.each { |m| m.accept(self) }
      if classDeclNode.super_class?
        classDeclNode.super_class.accept(self)
      end
      classDeclNode.interfaces.each { |i| i.accept(self) }
      classDeclNode.body.each { |b| b.accept(self) }
    end

    def visit(interfaceDeclNode : AST::InterfaceDecl) : Nil
      interfaceDeclNode.modifiers.each { |m| m.accept(self) }
      interfaceDeclNode.extensions.each { |i| i.accept(self) }
      interfaceDeclNode.body.each { |b| b.accept(self) }
    end

    def visit(simpleNameNode : AST::SimpleName) : Nil
    end

    def visit(qualifiedNameNode : AST::QualifiedName) : Nil
    end

    def visit(fieldDeclNode : AST::FieldDecl) : Nil
      fieldDeclNode.modifiers.each { |m| m.accept(self) }
      fieldDeclNode.typ.accept(self)
      fieldDeclNode.decl.accept(self)
    end

    def visit(fileNode : AST::File) : Nil
      if fileNode.package?
        fileNode.package.accept(self)
      end
      fileNode.imports.each { |i| i.accept(self) }
      fileNode.decls.each { |d| d.accept(self) }
    end

    def visit(paramNode : AST::Param) : Nil
      paramNode.typ.accept(self)
    end

    def visit(blockNode : AST::Block) : Nil
      blockNode.stmts.each { |s| s.accept(self) }
    end

    def visit(exprOpNode : AST::ExprOp) : Nil
      exprOpNode.operands.each { |o| o.accept(self) }
    end

    def visit(exprClassInitNode : AST::ExprClassInit) : Nil
      exprClassInitNode.name.accept(self)
      exprClassInitNode.args.each { |a| a.accept(self) }
    end

    def visit(exprThisNode : AST::ExprThis) : Nil
    end

    def visit(exprRefNode : AST::ExprRef) : Nil
      exprRefNode.name.accept(self)
    end

    def visit(constIntegerNode : AST::ConstInteger) : Nil
    end

    def visit(constBoolNode : AST::ConstBool) : Nil
    end

    def visit(constCharNode : AST::ConstChar) : Nil
    end

    def visit(constStringNode : AST::ConstString) : Nil
    end

    def visit(constNullNode : AST::ConstNull) : Nil
    end

    def visit(variableDeclNode : AST::VariableDecl) : Nil
      if variableDeclNode.init?
        variableDeclNode.init.accept(self)
      end
    end

    def visit(declStmtNode : AST::DeclStmt) : Nil
      declStmtNode.typ.accept(self)
      declStmtNode.var.accept(self)
    end

    def visit(methodDeclNode : AST::MethodDecl) : Nil
      methodDeclNode.typ.accept(self)
      methodDeclNode.modifiers.each { |m| m.accept(self) }
      methodDeclNode.params.each { |p| p.accept(self) }
      if methodDeclNode.body?
        methodDeclNode.body.each { |b| b.accept(self) }
      end
    end

    def visit(constructorDeclNode : AST::ConstructorDecl) : Nil
      constructorDeclNode.name.accept(self)
      constructorDeclNode.modifiers.each { |m| m.accept(self) }
      constructorDeclNode.params.each { |p| p.accept(self) }
      constructorDeclNode.body.each { |b| b.accept(self) }
    end
  end

  class ValueRangeVisitor < GenericVisitor
    def visit(constIntegerNode : AST::ConstInteger) : Nil
      puts "I found an integer! #{constIntegerNode.val}"
      super
    end
  end
end
