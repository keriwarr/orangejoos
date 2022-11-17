require "./compiler_errors.cr"
require "./ast.cr"
require "./visitor.cr"

# Weeding is a step that does specific program validations after
# parsing. It operates on the AST.
class Weeding
  def initialize(@root : AST::File, @public_class_name : String)
  end

  def weed
    @root.accept(InterfaceDeclVisitor.new)
    @root.accept(ClassDeclVisitor.new)
    @root.accept(PublicDeclVisitor.new)
    @root.accept(CheckPublicDeclNameVisitor.new(@public_class_name))
    @root.accept(InvalidInstanceOfExpressionVisitor.new)
  end
end

class InterfaceDeclVisitor < AST::Visitor
  def visit(node : AST::InterfaceDecl) : Nil
    node.body.each do |b|
      if b.is_a?(AST::MethodDecl) && (b.is_static? || b.is_final? || b.is_native?)
        # An interface method cannot be static, final, or native.
        raise WeedingStageError.new("interfaces cannot have final, static, or native functions: function #{b.name} was bad")
      end
    end

    super
  end
end

class ClassDeclVisitor < AST::Visitor
  def visit(node : AST::ClassDecl) : Nil
    found_constructor = false

    # A class annot be final and abstract.
    # See JLS 8.1.1.2 for more details
    if node.is_final? && node.is_abstract?
      raise WeedingStageError.new("class #{node.name} is both final and abstract.")
    end

    node.body.each do |b|
      case b
      when AST::ConstructorDecl
        handle_constructor_decl(node, b)
        found_constructor = true
      when AST::FieldDecl  then handle_field_decl(node, b)
      when AST::MethodDecl then handle_method_decl(node, b)
      end
    end

    if !node.is_abstract? && !found_constructor
      raise WeedingStageError.new("class #{node.name} has no constructors")
    end

    super
  end

  def handle_constructor_decl(node : AST::ClassDecl, cd : AST::ConstructorDecl)
    # Make sure all constructors have the correct name.
    if cd.name != node.name
      raise WeedingStageError.new("class #{node.name} has a constructor named #{cd.name}")
    end
  end

  def handle_field_decl(node : AST::ClassDecl, fd : AST::FieldDecl)
    # Do not allow fields to be final.
    if fd.is_final?
      raise WeedingStageError.new("field #{node.name}.#{fd.var.name} is final, but final is not allowed")
    end
  end

  def handle_method_decl(node : AST::ClassDecl, md : AST::MethodDecl)
    # A method requires an access modifier, either protected or public.
    if !md.is_public? && !md.is_protected?
      raise WeedingStageError.new("method #{node.name}.#{md.name} has no access modifier (public/private)")
    end

    # A method cannot be both static and final.
    if md.is_static? && md.is_final?
      raise WeedingStageError.new("method #{node.name}.#{md.name} cannot be both static and final")
    end

    # An abstract method cannot be static or final.
    if md.is_abstract? && (md.is_static? || md.is_final?)
      raise WeedingStageError.new("method #{node.name}.#{md.name} cannot be both abstract and static/final")
    end

    # An abstract method cannot have a body.
    if md.is_abstract? && md.body?
      raise WeedingStageError.new("method #{node.name}.#{md.name} is abstract but has a body")
    end

    # An non-abstract method requires a body.
    if !md.is_abstract? && !md.is_native? && !md.body?
      raise WeedingStageError.new("method #{node.name}.#{md.name} is not abstract but does not have a body")
    end

    # Restrict use of the native modifier to only methods
    # without a body and are static. Otherwise, if we encounter
    # native the function signature is invalid.
    if md.is_native? && md.is_static? && !md.body?
      # Allow signature.
    elsif md.is_native?
      raise WeedingStageError.new("method #{node.name}.#{md.name} is not allowed to be native if does not conform to the signature\n <Visibility> static native <Name>(...);")
    end
  end
end

class PublicDeclVisitor < AST::Visitor
  @public_classes = [] of String

  def visit(node : AST::TypeDecl) : Nil
    @public_classes.push(node.name) if node.is_public?
  end

  def on_completion
    if @public_classes.size > 1
      raise WeedingStageError.new("more than one class/interface is public, got: #{@public_classes}")
    end
  end
end

class CheckPublicDeclNameVisitor < AST::Visitor
  def initialize(@public_class_name : String)
  end

  def visit(node : AST::TypeDecl) : Nil
    if node.is_public? && node.name != @public_class_name
      raise WeedingStageError.new("class declared was \"#{node.name}\" but to match the file name it must be \"#{@public_class_name}\"")
    end
  end
end

class InvalidInstanceOfExpressionVisitor < AST::Visitor
  def visit(node : AST::ExprInstanceOf) : Nil
    typ_node = node.typ
    if typ_node.is_a?(AST::PrimitiveTyp) && typ_node.cardinality == 0
      raise WeedingStageError.new("Primitive types cannot be used in instanceof, node is: #{node.to_s}")
    end
  end
end
