require "./compiler_errors.cr"
require "./ast.cr"
require "./visitor.cr"
require "./source_file.cr"

# NameResolution is a step that resolves any name references found in
# the program. It will modify the AST to populate them where
# appropriate.
class NameResolution
  def initialize(@files : Array(SourceFile))
  end

  def generate_exported_items
    package_root = PackageNode.new

    @files.each do |file|
      ast = file.ast
      if ast.package?
        if ast.decl?(file.class_name)
          decl = ast.decl(file.class_name)
          typ = TypeNode.new(decl.name, decl)
          STDERR.puts "decl=#{decl.name} in package=#{ast.package.pprint}"
          package_root.add_child(ast.package.path.parts, typ)
        end
      end
    end

    return package_root
  end

  def resolve
    exported_items = generate_exported_items

    # DEBUG INFO
    classes = exported_items.enumerate
    STDERR.puts "==== EXPORTED ITEMS ===="
    STDERR.puts "#{classes.map(&.first).join("\n")}"

    return @files
  end
end


# PackageTree is the tree structure that holds all packages and types
# defined. These are elements that are referable via import paths.
abstract class PackageTree
  abstract def name : String
  abstract def enumerate : Array(Tuple(String, AST::TypeDecl))
end


class TypeNode < PackageTree
  getter name : String
  getter decl : AST::TypeDecl

  def initialize(@name : String, @decl : AST::TypeDecl)
  end

  def enumerate : Array(Tuple(String, AST::TypeDecl))
    return [Tuple.new(name, decl)]
  end
end

class PackageNode < PackageTree
  getter name : String
  getter children : Hash(String, PackageTree)

  @root = false

  def initialize(@name : String)
    @children = Hash(String, PackageTree).new
  end

  def initialize
    @name = ""
    @root = true
    @children = Hash(String, PackageTree).new
  end

  def add_child(parts : Array(String), node : TypeNode)
    if parts.size > 0
      children[parts.first] = PackageNode.new(parts.first) if !children.has_key?(parts.first)
      c = children[parts.first]
      if !c.is_a?(PackageNode)
        raise NameResolutionStageError.new("type decl is prefix of existing package path")
      end
      c.add_child(parts[1..parts.size], node)
    elsif children.has_key?(node.name)
        raise NameResolutionStageError.new("name #{node.name} already exists in package TODO")
    else
      children[node.name] = node
    end
  end

  def enumerate : Array(Tuple(String, AST::TypeDecl))
    return children.values.flat_map(&.enumerate) if @root

    return children.values.flat_map do |child|
      child.enumerate.map {|c_name, tree| Tuple.new(name + "." + c_name, tree)}
    end
  end
end
