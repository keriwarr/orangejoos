require "./compiler_errors.cr"
require "./ast.cr"
require "./visitor.cr"

# Weeding is a step that does specific program validations after
# parsing. It operates on the AST.
class Weeding
  def initialize(@root : AST::File, @public_class_name : String)
  end

  def weed
    # NOTE: when in doubt, assume that this ordering of visitors is necessary
    # TODO(keri): find a way to indicate visitor pre/post requisites
    @root.accept(InterfaceDeclVisitor.new)
    @root.accept(ClassDeclVisitor.new)
    @root.accept(PublicDeclVisitor.new)
    @root.accept(CheckPublicDeclNameVisitor.new(@public_class_name))
    @root.accept(ValueRangeVisitor.new)
    @root.accept(LiteralRangeCheckerVisitor.new)
  end
end

class InterfaceDeclVisitor < Visitor::GenericVisitor
  def visit(node : AST::InterfaceDecl) : AST::Node
    node.body.each do |b|
      if b.is_a?(AST::MethodDecl) && (b.has_mod("static") || b.has_mod("final") || b.has_mod("native"))
        # An interface method cannot be static, final, or native.
        raise WeedingStageError.new("interfaces cannot have final, static, or native functions: function #{b.name} was bad")
      end
    end

    return super
  end
end

class ClassDeclVisitor < Visitor::GenericVisitor
  def visit(node : AST::ClassDecl) : AST::Node
    found_constructor = false

    # A class annot be final and abstract.
    # TODO(joey): add reference to specific JLS section for rule.
    if node.has_mod("final") && node.has_mod("abstract")
      raise WeedingStageError.new("class #{node.name} is both final and abstract.")
    end

    node.body.each do |b|
      case b
      when AST::ConstructorDecl
        handleConstructorDecl(node, b)
        found_constructor = true
      when AST::FieldDecl then handleFieldDecl(node, b)
      when AST::MethodDecl then handleMethodDecl(node, b)
      end
    end

    if !node.has_mod("abstract") && !found_constructor
      raise WeedingStageError.new("class #{node.name} has no constructors")
    end

    return super
  end

  def handleConstructorDecl(node : AST::ClassDecl, cd : AST::ConstructorDecl)
    # Make sure all constructors have the correct name.
    if cd.name.name != node.name
      raise WeedingStageError.new("class #{node.name} has a constructor named #{cd.name.name}")
    end
  end

  def handleFieldDecl(node : AST::ClassDecl, fd : AST::FieldDecl)
    # Do not allow fields to be final.
    if fd.has_mod("final")
      raise WeedingStageError.new("field #{node.name}.#{fd.decl.name} is final, but final is not allowed")
    end
  end

  def handleMethodDecl(node : AST::ClassDecl, md : AST::MethodDecl)
    # A method requires an access modifier, either protected or public.
    if !md.has_mod("public") && !md.has_mod("protected")
      raise WeedingStageError.new("method #{node.name}.#{md.name} has no access modifier (public/private)")
    end

    # A method cannot be both static and final.
    if md.has_mod("static") && md.has_mod("final")
      raise WeedingStageError.new("method #{node.name}.#{md.name} cannot be both static and final")
    end

    # An abstract method cannot be static or final.
    if md.has_mod("abstract") && (md.has_mod("static") || md.has_mod("final"))
      raise WeedingStageError.new("method #{node.name}.#{md.name} cannot be both abstract and static/final")
    end

    # An abstract method cannot have a body.
    if md.has_mod("abstract") && md.body?
      raise WeedingStageError.new("method #{node.name}.#{md.name} is abstract but has a body")
    end

    # An non-abstract method requires a body.
    if !md.has_mod("abstract") && !md.has_mod("native") && !md.body?
      raise WeedingStageError.new("method #{node.name}.#{md.name} is not abstract but does not have a body")
    end

    # Restrict use of the native modifier to only methods
    # without a body and are static. Otherwise, if we encounter
    # native the function signature is invalid.
    if md.has_mod("native") && md.has_mod("static") && !md.body?
      # Allow signature.
    elsif md.has_mod("native")
      raise WeedingStageError.new("method #{node.name}.#{md.name} is not allowed to be native if does not conform to the signature\n <Visibility> static native <Name>(...);")
    end
  end
end

class PublicDeclVisitor < Visitor::GenericVisitor
  @public_classes = [] of String

  def visit(node : AST::TypeDecl) : AST::Node
    @public_classes.push(node.name) if node.has_mod("public")
    return node
  end

  def on_completion
    if @public_classes.size > 1
      raise WeedingStageError.new("more than one class/interface is public, got: #{@public_classes}")
    end
  end
end

class CheckPublicDeclNameVisitor < Visitor::GenericVisitor
  def initialize(@public_class_name : String)
  end

  def visit(node : AST::TypeDecl) : AST::Node
    # TODO(keri): implement .is_public? ??
    if node.has_mod("public") && node.name != @public_class_name
      raise WeedingStageError.new("class declared was \"#{node.name}\" but to match the file name it must be \"#{@public_class_name}\"")
    end
    return node
  end
end

class ValueRangeVisitor < Visitor::GenericVisitor
  def visit(node : AST::ExprOp) : AST::Node
    if node.op == "-" && node.operands.size == 1 && node.operands[0].is_a?(AST::ConstInteger)
      constInteger = node.operands[0].as(AST::ConstInteger)
      constInteger.val = "-" + constInteger.val
      return constInteger
    end
    return super
  end
end

class LiteralRangeCheckerVisitor < Visitor::GenericVisitor
  def visit(node : AST::ConstInteger) : AST::Node
    begin
      node.val.to_i32
    rescue ArgumentError
      raise WeedingStageError.new("Integer out of bounds")
    end
    return node
  end
end
