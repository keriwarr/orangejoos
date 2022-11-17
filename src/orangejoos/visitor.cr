require "./ast.cr"
require "./compiler_errors.cr"

module AST
  abstract class Visitor
  end

  class Visitor
    # Last child stack represents whether each node which is currently being
    # visited was the last child of it's parent
    # In particular, this can be used to decide how to pretty print an AST
    # i.e. which box drawing characters to use
    @last_child_stack = [] of Bool
    # Used to to the descend method which value to push onto @last_child_stack
    @is_last_child = false
    @depth = 0

    def descend
      @depth += 1
      @last_child_stack.push(@is_last_child)
      @is_last_child = false
    end

    def ascend
      @last_child_stack.pop
      @depth -= 1
      on_completion if @depth == 0
    end

    def on_completion
    end

    def visit(node : Node) : Nil
      if !node.ast_children.empty?
        node.ast_children[0..-2].each { |c| c.accept(self) }
        @is_last_child = true
        node.ast_children.last.accept(self)
      end
    rescue ex : CompilerError
      case node
      when ClassDecl
        ex.register("class_name", node.name)
      when InterfaceDecl
        ex.register("interface_name", node.name)
      when MethodDecl
        ex.register("method", node.name)
      when ConstructorDecl
        ex.register("constructor", "")
      end
      raise ex
    end
  end

  abstract class Node
    def accept(v : Visitor) : Nil
      v.descend
      v.visit(self)
      v.ascend
    end
  end
end
