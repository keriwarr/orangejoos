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

class InterfaceDeclVisitor < Visitor::GenericVisitor
  def visit(node : AST::InterfaceDecl) : Nil
    node.body.each do |b|
      if b.is_a?(AST::MethodDecl) && (b.has_mod?(AST::Modifier::STATIC) || b.has_mod?(AST::Modifier::FINAL) || b.has_mod?(AST::Modifier::NATIVE))
        # An interface method cannot be static, final, or native.
        raise WeedingStageError.new("interfaces cannot have final, static, or native functions: function #{b.name} was bad")
      end
    end

    super
  end
end

class ClassDeclVisitor < Visitor::GenericVisitor
  def visit(node : AST::ClassDecl) : Nil
    found_constructor = false

    # A class annot be final and abstract.
    # See JLS 8.1.1.2 for more details
    if node.has_mod?(AST::Modifier::FINAL) && node.has_mod?(AST::Modifier::ABSTRACT)
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

    if !node.has_mod?(AST::Modifier::ABSTRACT) && !found_constructor
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
    if fd.has_mod?(AST::Modifier::FINAL)
      raise WeedingStageError.new("field #{node.name}.#{fd.var.name} is final, but final is not allowed")
    end
  end

  def handle_method_decl(node : AST::ClassDecl, md : AST::MethodDecl)
    # A method requires an access modifier, either protected or public.
    if !md.has_mod?(AST::Modifier::PUBLIC) && !md.has_mod?(AST::Modifier::PROTECTED)
      raise WeedingStageError.new("method #{node.name}.#{md.name} has no access modifier (public/private)")
    end

    # A method cannot be both static and final.
    if md.has_mod?(AST::Modifier::STATIC) && md.has_mod?(AST::Modifier::FINAL)
      raise WeedingStageError.new("method #{node.name}.#{md.name} cannot be both static and final")
    end

    # An abstract method cannot be static or final.
    if md.has_mod?(AST::Modifier::ABSTRACT) && (md.has_mod?(AST::Modifier::STATIC) || md.has_mod?(AST::Modifier::FINAL))
      raise WeedingStageError.new("method #{node.name}.#{md.name} cannot be both abstract and static/final")
    end

    # An abstract method cannot have a body.
    if md.has_mod?(AST::Modifier::ABSTRACT) && md.body?
      raise WeedingStageError.new("method #{node.name}.#{md.name} is abstract but has a body")
    end

    # An non-abstract method requires a body.
    if !md.has_mod?(AST::Modifier::ABSTRACT) && !md.has_mod?(AST::Modifier::NATIVE) && !md.body?
      raise WeedingStageError.new("method #{node.name}.#{md.name} is not abstract but does not have a body")
    end

    # Restrict use of the native modifier to only methods
    # without a body and are static. Otherwise, if we encounter
    # native the function signature is invalid.
    if md.has_mod?(AST::Modifier::NATIVE) && md.has_mod?(AST::Modifier::STATIC) && !md.body?
      # Allow signature.
    elsif md.has_mod?(AST::Modifier::NATIVE)
      raise WeedingStageError.new("method #{node.name}.#{md.name} is not allowed to be native if does not conform to the signature\n <Visibility> static native <Name>(...);")
    end
  end
end

class PublicDeclVisitor < Visitor::GenericVisitor
  @public_classes = [] of String

  def visit(node : AST::TypeDecl) : Nil
    @public_classes.push(node.name) if node.has_mod?(AST::Modifier::PUBLIC)
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

  def visit(node : AST::TypeDecl) : Nil
<<<<<<< HEAD
    if node.has_mod?("public") && node.name != @public_class_name
=======
    # TODO(keri): implement .is_public? ??
    if node.has_mod?(AST::Modifier::PUBLIC) && node.name != @public_class_name
>>>>>>> change Modifier to proper ENUM
      raise WeedingStageError.new("class declared was \"#{node.name}\" but to match the file name it must be \"#{@public_class_name}\"")
    end
  end
end

class InvalidInstanceOfExpressionVisitor < Visitor::GenericVisitor
  def visit(node : AST::ExprInstanceOf) : Nil
    typ_node = node.typ
    if typ_node.is_a?(AST::PrimitiveTyp) && typ_node.cardinality == 0
      raise WeedingStageError.new("Primitive types cannot be used in instanceof, node is: #{node.to_s}")
    end
  end
end
