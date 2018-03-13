
require "./visitor"


module AST
  # Note : Most exprs not visited, to_s used instaed
  class ASTPrinterVisitor < Visitor::GenericVisitor
    def print(str : String) : Nil
      if @last_child_stack.size <= 1
        STDERR.puts str
        return
      end

      indent_str = ""
      @last_child_stack[1..-2].each do |last_child|
        if last_child
          indent_str += "  "
        else
          indent_str += "│ "
        end
      end
      if @last_child_stack.last
        indent_str += "└─"
      else
        indent_str += "├─"
      end

      STDERR.puts "#{indent_str}#{str}"
    end

    def indent(last : Bool = true) : Nil
      @last_child_stack.push(last)
    end

    def outdent() : Nil
      @last_child_stack.pop
    end

    def print_child(str : String, last : Bool = false) : Nil
      indent(last)
      print str
      outdent
    end

    def visit(node : AST::PrimitiveTyp) : Nil
      print "PrimitiveTyp: #{node.name_str}"
      super
    end

    def visit(node : AST::ReferenceTyp) : Nil
      print "ReferenceTyp: #{node.name_str}"
      super
    end

    def visit(node : AST::Literal) : Nil
      print "Literal: #{node.val}"
      super
    end

    def visit(node : AST::Keyword) : Nil
      print "Keyword: #{node.val}"
      super
    end

    def visit(node : AST::PackageDecl) : Nil
      print "Package: #{node.path.name}"
      super
    end

    def visit(node : AST::ImportDecl) : Nil
      print "Import:  #{node.path.name}#{node.on_demand ? ".*" : ""}"
      super
    end

    def visit(node : AST::ClassDecl) : Nil
      print "Class:   #{node.name}"
      last_child = node.ast_children.empty?
      print_child("Modifiers: #{node.modifiers.join(", ")}", last_child)
      super
    end

    def visit(node : AST::InterfaceDecl) : Nil
      print "Interface: node.name"
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

    def visit(node : AST::DeclStmt) : Nil
      print "DeclStmt: typ={#{node.typ.name_str}}"
      visit([node.var.as(Node)])
      # no super
    end

    def visit(node : AST::ForStmt) : Nil
      print "ForStmt:"
      print_child("Init:")
      indent(false)
      visit([node.init.as(Node)])
      outdent
      print_child "Test: #{node.expr.to_s}" if node.expr?
      print_child("Update:")
      indent(false)
      visit([node.update.as(Node)])
      outdent
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
      print "Method: #{node.name}"
      print_child "Modifiers: #{node.modifiers.join(", ")}"
      print_child "Returns: #{node.typ.to_s}"
      last_child = !node.body?
      print_child("Params: #{(node.params.map {|i| i.to_s}).join(", ")}", last_child) if !node.params.empty?
      if node.body?
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
      # FIXME: params aren't printing
      last_child = node.body.empty?
      print_child("Params: #{(node.params.map {|i| i.to_s}).join(", ")}", last_child) if !node.params.empty?
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
