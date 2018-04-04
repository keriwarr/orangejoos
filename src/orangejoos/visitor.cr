require "./ast.cr"
require "./compiler_errors.cr"

module Visitor
  abstract class Visitor
    @depth = 0

    abstract def visit(node : AST::PrimitiveTyp) : Nil
    abstract def visit(node : AST::ClassTyp) : Nil
    abstract def visit(node : AST::Identifier) : Nil
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
    abstract def visit(node : AST::VarDeclStmt) : Nil
    abstract def visit(node : AST::ForStmt) : Nil
    abstract def visit(node : AST::WhileStmt) : Nil
    abstract def visit(node : AST::IfStmt) : Nil
    abstract def visit(node : AST::MethodInvoc) : Nil
    abstract def visit(node : AST::ExprArrayAccess) : Nil
    abstract def visit(node : AST::ExprArrayInit) : Nil
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

  # GenericVisitor has some behaviours which were added to facilitate pretty printing
  class GenericVisitor < Visitor
    # Last child stack represents whether each node which is currently being visited was the last
    # child of it's parent
    # In particular, this can be used to decide how to pretty print an AST
    # i.e. which box drawing characters to use
    @last_child_stack = [] of Bool
    # Used to to the descend method which value to push onto @last_child_stack
    @is_last_child = false

    def descend
      super

      @last_child_stack.push(@is_last_child)
      @is_last_child = false
    end

    def ascend
      super

      @last_child_stack.pop
    end

    def visit(children : Array(AST::Node)) : Nil
      if !children.empty?
        children[0..-2].each { |c| c.accept(self) }
        @is_last_child = true
        children.last.accept(self)
      end
    end

    def visit(node : AST::PrimitiveTyp) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ClassTyp) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::Identifier) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::PackageDecl) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ImportDecl) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::Modifier) : Nil
      raise Exception.new("should not be executed")
    end

    def visit(node : AST::ClassDecl) : Nil
      visit(node.ast_children)
    rescue ex : CompilerError
      ex.register("class_name", node.name)
      raise ex
    end

    def visit(node : AST::InterfaceDecl) : Nil
      visit(node.ast_children)
    rescue ex : CompilerError
      ex.register("interface_name", node.name)
      raise ex
    end

    def visit(node : AST::SimpleName) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::QualifiedName) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::FieldDecl) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::File) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::Param) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::Block) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ExprOp) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ExprInstanceOf) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ExprClassInit) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ExprThis) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ExprFieldAccess) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ExprRef) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ConstInteger) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ConstBool) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ConstChar) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ConstString) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ConstNull) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::VariableDecl) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::VarDeclStmt) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ForStmt) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::WhileStmt) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::IfStmt) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::MethodInvoc) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ExprArrayAccess) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ExprArrayInit) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::MethodDecl) : Nil
      visit(node.ast_children)
    rescue ex : CompilerError
      ex.register("method", node.name)
      raise ex
    end

    def visit(node : AST::ConstructorDecl) : Nil
      visit(node.ast_children)
    rescue ex : CompilerError
      ex.register("constructor", "")
      raise ex
    end

    def visit(node : AST::ReturnStmt) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::CastExpr) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::ParenExpr) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::Variable) : Nil
      visit(node.ast_children)
    end

    def visit(node : AST::Modifier) : Nil
      raise Exception.new("should not be executed")
    end
  end
end
