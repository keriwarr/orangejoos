require "./compiler_errors.cr"
require "./ast.cr"
require "./visitor.cr"

# Weeding is a step that does specific program validations after
# parsing. It operates on the AST.
class Weeding
  def initialize(@root : AST::File, @public_class_name : String)
  end

  def weed
    public_classes = [] of String

    @root.decls.each do |decl|
      # If the interface or class is public, add record it. We later
      # check to make sure that there is only one public type and that
      # the name matches the file name.
      if decl.has_mod("public")
        public_classes.push(decl.name)
      end

      # A class annot be final and abstract.
      # TODO(joey): add reference to specific JLS section for rule.
      if decl.is_a?(AST::ClassDecl) && decl.has_mod("final") && decl.has_mod("abstract")
        raise WeedingStageError.new("class #{decl.name} is both final and abstract.")
      end


      if decl.is_a?(AST::ClassDecl)
        # Check to make sure there is at least one constructor.
        found_constructor = false
        decl.body.each do |body|
          # Make sure all constructors have the correct name.
          if body.is_a?(AST::ConstructorDecl)
            found_constructor = true
            if body.name.name != decl.name
              raise WeedingStageError.new("class #{decl.name} has a constructor named #{body.name.name}")
            end
          end

          if body.is_a?(AST::MethodDecl)
            # A method requires an access modifier, either protected or public.
            if !body.has_mod("public") && !body.has_mod("protected")
              raise WeedingStageError.new("method #{decl.name}.#{body.name} has no access modifier (public/private)")
            end

            # A method cannot be both static and final.
            if body.has_mod("static") && body.has_mod("final")
              raise WeedingStageError.new("method #{decl.name}.#{body.name} cannot be both static and final")
            end

            # An abstract method cannot be static or final.
            if body.has_mod("abstract") && (body.has_mod("static") || body.has_mod("final"))
              raise WeedingStageError.new("method #{decl.name}.#{body.name} cannot be both abstract and static/final")
            end

            # An abstract method cannot have a body.
            if body.has_mod("abstract") && body.body?
              raise WeedingStageError.new("method #{decl.name}.#{body.name} is abstract but has a body")
            end

            # An non-abstract method requires a body.
            if !body.has_mod("abstract") && !body.has_mod("native") && !body.body?
              raise WeedingStageError.new("method #{decl.name}.#{body.name} is not abstract but does not have a body")
            end

            # Restrict use of the native modifier to only methods
            # without a body and are static. Otherwise, if we encounter
            # native the function signature is invalid.
            if body.has_mod("native") && body.has_mod("static") && !body.body?
              # Allow signature.
            elsif body.has_mod("native")
              raise WeedingStageError.new("method #{decl.name}.#{body.name} is not allowed to be native if does not conform to the signature\n <Visibility> static native <Name>(...);")
            end
          elsif body.is_a?(AST::FieldDecl)
            # Do not allow fields to be final.
            if body.has_mod("final")
              raise WeedingStageError.new("field #{decl.name}.#{body.decl.name} is final, but final is not allowed")
            end
          end
        end # @rools.decls

        if !decl.has_mod("abstract") && !found_constructor
          raise WeedingStageError.new("class #{decl.name} has no constructors")
        end
      end

      if decl.is_a?(AST::InterfaceDecl)
        decl.body.each do |body|
          # An interface cannot have fields.
          # FIXME(joey): This is not required anymore as the grammar
          # rule was removed.
          if body.is_a?(AST::FieldDecl)
            raise WeedingStageError.new("interfaces are not allowed to have fields: #{decl.name} has field #{body.pprint(0)}")
          end

          if body.is_a?(AST::MethodDecl)
            # An interface method cannot be static, final, or native.
            if body.has_mod("static") || body.has_mod("final") || body.has_mod("native")
              raise WeedingStageError.new("interfaces cannot have final, static, or native functions: function #{body.name} was bad")
            end
          end
        end
      end
    end

    # Ensure there is only one public type, and that it matches the file name.
    if public_classes.size > 1
      raise WeedingStageError.new("more than one class/interface is public, got: #{public_classes}")
    elsif public_classes.size == 1 && public_classes.first != @public_class_name
      raise WeedingStageError.new("class declared was \"#{public_classes.first}\" but to match the file name it must be \"#{@public_class_name}\"")
    end

    @root.accept(Visitor::ValueRangeVisitor.new)
    @root.accept(Visitor::LiteralRangeCheckerVisitor.new)
  end
end
