require "./compiler_errors"
require "./ast"
require "./visitor"
require "./source_file"

# NameResolution is a step that resolves any name references found in
# the program. It will modify the AST to populate them where
# appropriate.
class NameResolution
  def initialize(@files : Array(SourceFile), @verbose : Bool)
  end

  def generate_exported_items(files)
    package_root = PackageNode.new

    files.each do |file|
      ast = file.ast
      if ast.package?
        if ast.decl?(file.class_name)
          decl = ast.decl(file.class_name)
          typ = TypeNode.new(decl.name, decl)
          if @verbose && !ast.package.path.name.starts_with? "java."
            STDERR.puts "decl=#{decl.name} in package=#{ast.package.pprint}"
          end
          package_root.add_child(ast.package.path.parts, typ)
        end
      end
    end

    return package_root
  end

  def populate_imports(file, exported_items)
    # These are populated separately because this defines the name
    # resolution priority. The order is:
    # 1) Try enclosed (same-file) class or interface
    # 2) Try any single-type import (A.B.C.D)
    # 3) Try same package import.
    # 4) Try any import-on-demand package (A.B.C.*) including java.lang.*
    # 5) System packages implicitly imported from java.lang.*
    single_type_imports = [] of Tuple(String, AST::TypeDecl)
    same_package_imports = [] of Tuple(String, AST::TypeDecl)
    on_demand_imports = [] of Tuple(String, AST::TypeDecl)
    system_imports = [] of Tuple(String, AST::TypeDecl)

    ast = file.ast
    imports = ast.imports.flat_map do |import|
      import_tree = exported_items.get(import.path.parts)
      prefix = import.path.parts[0...import.path.parts.size - 1].join(".")
      prefix += "." if prefix.size > 0
      if import_tree.is_a?(TypeNode)
        single_type_imports += import_tree.enumerate(prefix)
      elsif import_tree.is_a?(PackageNode) && import.on_demand
        if import.path.name == "java.lang"
          system_imports += import_tree.enumerate(prefix)
        else
          on_demand_imports += import_tree.enumerate(prefix)
        end
      else
        raise NameResolutionStageError.new("cannot single-type-import a package, only Class or Interfaces: violate file #{file.path} import #{import.path.pprint}")
      end
    end

    # Import java.lang.*, which is by default always imported at a
    # lower priority.
    import = AST::ImportDecl.new(AST::QualifiedName.new(["java", "lang"]), true)
    import_tree = exported_items.get(import.path.parts)
    prefix = import.path.parts[0...import.path.parts.size - 1].join(".")
    prefix += "." if prefix.size > 0
    if import_tree.is_a?(TypeNode)
      raise NameResolutionStageError.new("error importing java.lang.* stdlib")
    elsif import_tree.is_a?(PackageNode) && import.on_demand
      system_imports += import_tree.enumerate(prefix)
    else
      raise NameResolutionStageError.new("error importing java.lang.* stdlib")
    end

    # Import all objects that exist in the internal package.
    if file.ast.package?
      import_tree = exported_items.get(file.ast.package.path.parts)
      prefix = import.path.parts[0...import.path.parts.size - 1].join(".")
      prefix += "." if prefix.size > 0
      same_package_imports += import_tree.enumerate(prefix)
    end

    same_file_imports = file.ast.decls.map {|decl| Tuple.new(decl.name, decl)}

    namespace = ImportNamespace.new(
      same_file_imports,
      single_type_imports,
      same_package_imports,
      on_demand_imports,
      system_imports,
    )


    file.same_file_imports = same_file_imports.map(&.first)
    file.single_type_imports = single_type_imports.map(&.first)
    file.same_package_imports = same_package_imports.map(&.first)
    file.on_demand_imports = on_demand_imports.map(&.first)
    file.system_imports = system_imports.map(&.first)

    return namespace
  end


  def resolve_inheritance(file, namespace)
    # ast = file.ast.accept(InterfaceResolutionVisitor.new(namespace))
    ast = file.ast.accept(ClassResolutionVisitor.new(namespace))

    return file.ast
  end


  def resolve
    exported_items = generate_exported_items(@files)

    # DEBUG INFO
    classes = exported_items.enumerate
    if @verbose
      STDERR.puts "=== EXPORTED ITEMS ==="
      STDERR.puts "#{classes.map(&.first).reject(&.starts_with? "java.").join("\n")}\n\n"
    end

    # Populate the imports for each file in-place.
    files = @files.map {|file| Tuple.new(file, populate_imports(file, exported_items)) }

    # Populate the inheritance information for the interfaces and
    # classes in each file.
    # FIXME(joey): Do we want to modify file.ast in-place? probably ok
    files = files.map {|file, namespace| file.ast = resolve_inheritance(file, namespace)}

    return @files
  end
end


# PackageTree is the tree structure that holds all packages and types
# defined. These are elements that are referable via import paths.
abstract class PackageTree
  abstract def name : String
  abstract def enumerate : Array(Tuple(String, AST::TypeDecl))
  abstract def get(path : Array(String)) : PackageTree
end


class TypeNode < PackageTree
  getter name : String
  getter decl : AST::TypeDecl

  def initialize(@name : String, @decl : AST::TypeDecl)
  end

  def enumerate(prefix : String = ""): Array(Tuple(String, AST::TypeDecl))
    return [Tuple.new(prefix + name, decl)]
  end

  def get(path : Array(String))
    if path.size > 0
      raise NameResolutionStageError.new("import path not valid")
    end
    return self
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
    # STDERR.puts "parts=#{parts} node=#{node.name}"
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

  def enumerate(prefix : String = "") : Array(Tuple(String, AST::TypeDecl))
    return children.values.flat_map(&.enumerate).map {|k, v| Tuple.new(prefix + k, v)} if @root

    return children.values.flat_map do |child|
      child.enumerate.map {|c_name, tree| Tuple.new(prefix + name + "." + c_name, tree)}
    end
  end

  def get(path : Array(String))
    if path.size > 0 && children.has_key?(path.first)
      return children[path.first].get(path[1..path.size])
    elsif path.size > 0
      raise NameResolutionStageError.new("path does not exist: #{path}")
    else
      return self
    end
  end
end


class InterfaceResolutionVisitor < Visitor::GenericVisitor
  @namespace : ImportNamespace

  def initialize(@namespace : ImportNamespace)
  end

  def visit(node : AST::InterfaceDecl) : AST::Node
    node.extensions.each do |name|
      STDERR.puts "interface=#{node.name} extension=#{name.name}"
    end

    return super
  end
end

class ClassResolutionVisitor < Visitor::GenericVisitor
  @namespace : ImportNamespace

  def initialize(@namespace : ImportNamespace)
  end

  def visit(node : AST::ClassDecl) : AST::Node
    interfaces = node.interfaces.map {|interface| interface.name}
    STDERR.puts "class=#{node.name} super=#{node.super_class? ? node.super_class.name : nil} interfaces=#{interfaces}"
    return super
  end
end

class ImportNamespace
  property same_file : Array(Tuple(String, AST::TypeDecl))
  property single_type : Array(Tuple(String, AST::TypeDecl))
  property same_package : Array(Tuple(String, AST::TypeDecl))
  property on_demand : Array(Tuple(String, AST::TypeDecl))
  property system : Array(Tuple(String, AST::TypeDecl))

  def initialize(
    @same_file : Array(Tuple(String, AST::TypeDecl)),
    @single_type : Array(Tuple(String, AST::TypeDecl)),
    @same_package : Array(Tuple(String, AST::TypeDecl)),
    @on_demand : Array(Tuple(String, AST::TypeDecl)),
    @system : Array(Tuple(String, AST::TypeDecl)),
  )
  end

  def has_type(name : String)
    return true
  end
end
