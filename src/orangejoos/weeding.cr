require "./compiler_errors.cr"
require "./ast.cr"

# Weeding is a step that does specific program validations after
# parsing. It operates on the AST.
class Weeding
  def initialize(@root : AST::File)
  end

  def weed
    @root.decls.each do |decl|
      # TODO(joey): add reference to specific JLS section for rule.
      if decl.is_a?(AST::ClassDecl) && decl.has_mod("final") && decl.has_mod("abstract")
        raise WeedingStageError.new("class #{decl.name} is both final and abstract.")
      end
    end
  end
end
