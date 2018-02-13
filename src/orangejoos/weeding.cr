require "./compiler_errors.cr"
require "./ast.cr"

# Weeding is a step that does specific program validations after
# parsing. It operates on the AST.
class Weeding
  def initialize(@root : AST::File)
  end

  def weed
  end
end
