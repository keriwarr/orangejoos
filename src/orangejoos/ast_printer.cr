require "./visitor"

module AST
  # A visitor which pretty prints the entire AST to STDERR
  #
  # Note that Exprs are not recursively visited. Instead, we call .to_s on them
  #
  # .visit can be implemented on a new node as follows:
  # If it is a simple node whose ast_children all know how to print themselves,
  # just call print, followed by super
  # If it has ast_children which are exprs, and you wish to qualify the printing of that
  # expr with an explanation such as "init={...}", you can print that expr with print_child
  # you shoud then explicitly call visit() on the remaining ast_children, and no call super.
  # If it has ast_children which don't have to_s implemented (such as stmts) that you wish
  # to qualify with an explanation, you can print these by calling `print_child` with the
  # description, then call indent, then explicitly visit that a child, then call outdent.
  # See visit(AST::ForStmt) for an example of ths.
  class ASTPrinterVisitor < Visitor::GenericVisitor
    def print(str : String) : Nil
      # This should only be true for the top-level node: AST::File
      if @last_child_stack.size <= 1
        STDERR.puts str
        return
      end

      # For each visited node, we build up an string to prepend to that node's description
      # which allows us to visualize the tree higherarchy of the AST
      indent_str = ""

      # Element 0 of the @last_child_stack represents the top-level node, so we ignore it
      # Thus, @last_child_stack[1..-2] represents the all the nodes that are being visited
      # except the first and the last. Since we're not currently visiting these nodes,
      # we don't want to print a box diagram which shows a line going to the right.
      @last_child_stack[1..-2].each do |last_child|
        if last_child
          indent_str += "  "
        else
          indent_str += "│ "
        end
      end

      # The last element of the stack represents the node we're currently visiting. We want
      # to print a box diagram which does show a line going to the right.
      if @last_child_stack.last
        indent_str += "└─"
      else
        indent_str += "├─"
      end

      STDERR.puts "#{indent_str}#{str}"
    end

    # We use this method to tell the visitor to simulate going a level deeper within the
    # AST in terms of what is being printed.
    # This allows us to have single nodes which print on multiple successive indentation
    # levels. This is very useful for the most complicated Nodes such as ClassDecls.
    def indent(last : Bool = true) : Nil
      @last_child_stack.push(last)
    end

    # All useages of indent should be paired to a corresponding call to outdent
    def outdent : Nil
      @last_child_stack.pop
    end

    # This is used to directly print a line which is drawn as a child of the current
    # node in the printed AST diagram
    def print_child(str : String, last : Bool = false) : Nil
      indent(last)
      print str
      outdent
    end

    def visit(node : AST::PrimitiveTyp) : Nil
      print "PrimitiveTyp: #{node.to_s}"
      super
    end

    def visit(node : AST::ClassTyp) : Nil
      print "ClassTyp: #{node.to_s}"
      # no super
    end

    def visit(node : AST::Identifier) : Nil
      print "Identifier: #{node.val}"
      super
    end

    def visit(node : AST::PackageDecl) : Nil
      print "Package: #{node.path.name}"
      super
    end

    def visit(node : AST::ImportDecl) : Nil
      print "Import:  #{node.path.name}#{node.on_demand ? ".*" : ""}"
      # no super
    end

    def visit(node : AST::ClassDecl) : Nil
      print "Class:   #{node.name}"
      last_child = node.ast_children.empty?
      print_child("Modifiers: #{node.modifiers.join(", ")}", last_child)
      super
    end

    def visit(node : AST::InterfaceDecl) : Nil
      print "Interface: #{node.name}"
      last_child = node.ast_children.empty?
      print_child("Modifiers: #{node.modifiers.join(", ")}", last_child)
      super
    end

    def visit(node : AST::SimpleName) : Nil
      print "SimpleName: #{node.name}"
      super
    end

    def visit(node : AST::QualifiedName) : Nil
      print "QualifiedName: #{node.name}"
      super
    end

    def visit(node : AST::FieldDecl) : Nil
      print "Field:"
      print_child "Modifiers: #{node.modifiers.join(", ")}"
      super
    end

    def visit(node : AST::File) : Nil
      print "File:"
      super
    end

    def visit(node : AST::Param) : Nil
      raise Exception.new("should not be executed")
    end

    def visit(node : AST::Block) : Nil
      print "Block:"
      super
    end

    def visit(node : AST::VariableDecl) : Nil
      print "VarDecl: #{node.name}"
      print_child("Init: {#{node.init.to_s}}", true) if node.init?
      # no super
    end

    def visit(node : AST::VarDeclStmt) : Nil
      print "VarDeclStmt: typ={#{node.typ.to_s}}"
      visit([node.var.as(Node)])
      # no super
    end

    def visit(node : AST::ForStmt) : Nil
      print "ForStmt:"
      if node.init?
        print_child("Init:")
        indent(false)
        visit([node.init.as(Node)])
        outdent
      end
      print_child "Test: #{node.expr.to_s}" if node.expr?
      if node.update?
        print_child("Update:")
        indent(false)
        visit([node.update.as(Node)])
        outdent
      end
      print_child("Body:", true)
      indent
      visit([node.body.as(Node)])
      outdent
      # no super
    end

    def visit(node : AST::WhileStmt) : Nil
      print "WhileStmt:"
      print_child "Test: #{node.expr.to_s}"
      print_child("Body:", true)
      indent
      visit([node.body.as(Node)])
      outdent
      # no super
    end

    def visit(node : AST::IfStmt) : Nil
      print "IfStmt:"
      print_child "Test: #{node.expr.to_s}"
      last_child = !node.else_body?
      print_child("If True:", last_child)
      indent last_child
      visit([node.if_body.as(Node)])
      outdent
      if node.else_body?
        print_child("Else:", true)
        indent
        visit([node.else_body.as(Node)])
        outdent
      end
      # no super
    end

    def visit(node : AST::MethodDecl) : Nil
      if !node.body? || node.body.empty?
        print "Method: #{node.name} <no body>"
      else
        print "Method: #{node.name}"
      end
      print_child "Modifiers: #{node.modifiers.join(", ")}"
      last_child = node.params.empty? && (!node.body? || node.body.empty?)
      if node.typ?
        print_child("Returns: #{node.typ.to_s}", last_child)
      else
        print_child("Returns: void", last_child)
      end
      last_child = !node.body? || node.body.empty?
      print_child("Params: #{(node.params.map { |i| i.to_s }).join(", ")}", last_child) if !node.params.empty?
      if node.body? && !node.body.empty?
        print_child("Body:", true)
        indent
        visit([node.body.map &.as(Node)].flatten.compact)
        outdent
      end
      # no super
    end

    def visit(node : AST::ConstructorDecl) : Nil
      if node.body.empty?
        print "Constructor: <no body>"
      else
        print "Constructor:"
      end
      last_child = node.body.empty? && node.params.empty?
      print_child("Modifiers: #{node.modifiers.join(", ")}", last_child)
      last_child = node.body.empty?
      print_child("Params: #{(node.params.map { |i| i.to_s }).join(", ")}", last_child) if !node.params.empty?
      if !node.body.empty?
        print_child("Body:", true)
        indent
        visit([node.body.map &.as(Node)].flatten)
        outdent
      end
      # no super
    end

    def visit(node : AST::ReturnStmt) : Nil
      print "Return: {#{node.expr? ? node.expr.to_s : ""}}"
      # no super
    end

    def visit(node : AST::Expr) : Nil
      print node.to_s
      # no super
    end
  end
end
