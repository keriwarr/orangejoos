require "ordered_hash"

class VTable
  # @table : OrderedHash(AST::TypeDecl, OrderedHash(AST::MethodDecl, String))

  # This needs to traverse each AST for each source file and generate a huge fucking
  # VTable for everything
  def initialize(sources : Array(SourceFile))
    # populate all interfaces

    # populate class methods

  end
end
