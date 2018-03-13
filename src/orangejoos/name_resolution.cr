require "./compiler_errors"
require "./ast"
require "./visitor"
require "./source_file"

# ROOT_PACKAGE is a special sentinel package that undeclared packages
# fall into. This is common for main.
ROOT_PACKAGE = [""]

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
        package_parts = ast.package.path.parts
      else
        package_parts = ROOT_PACKAGE
      end

      # FIXME(joey): We need to handle the specifics for protected
      # classes that are available within the same package or the root
      # package.
      if ast.decl?(file.class_name)
        decl = ast.decl(file.class_name)
        typ = TypeNode.new(decl.name, decl)
        package_root.add_child(package_parts, typ)
      end
    end

    # Add qualified names to each `TypeDecl`.
    files.each do |file|
      ast = file.ast
      if ast.package?
        package = ast.package.path.name
      else
        package = ""
      end
      ast.decls.each do |decl|
        decl.qualified_name = "#{package}.#{decl.name}"
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
    else
      # If nothing is exported in the root package we need to check first.
      if exported_items.has_path?("")
        import_tree = exported_items.get(ROOT_PACKAGE)
        # These get created with a "."" prefix that needs to be removed.
        same_package_imports += import_tree.enumerate("")
        same_package_imports = same_package_imports.map {|s, n| Tuple.new(s[1..s.size], n)}
      end
    end

    same_file_imports = file.ast.decls.map {|decl| Tuple.new(decl.name, decl)}

    full_namespace = exported_items.enumerate

    namespace = ImportNamespace.new(
      same_file_imports,
      single_type_imports,
      same_package_imports,
      on_demand_imports,
      system_imports,
      full_namespace,
    )

    file.same_file_imports = same_file_imports.map(&.first)
    file.single_type_imports = single_type_imports.map(&.first)
    file.same_package_imports = same_package_imports.map(&.first)
    file.on_demand_imports = on_demand_imports.map(&.first)
    file.system_imports = system_imports.map(&.first)

    return namespace
  end


  def resolve_inheritance(file, namespace, cycle_tracker)
    # FIXME(joey): Maybe it would be great to replace Name instances
    # with QualifiedNameResolution for doing better static assertion of
    # resolution?
    file.ast.accept(InterfaceResolutionVisitor.new(namespace))
    file.ast.accept(ClassResolutionVisitor.new(namespace))

    # Check for clashes of the namespace with any classes defined in the
    # file.
    # TODO(joey): Check that any decl in file.ast does not class with
    # anything in namespace (excluding the single exported type that
    # comes from this file).

    file.ast.accept(CycleVisitor.new(namespace, cycle_tracker))
    file.ast.accept(ClassTypResolutionVisitor.new(namespace))
    return file
  end

  def check_correctness(file)
    file.ast.accept(DuplicateFieldVisitor.new)
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

    files.each do |f, _|
      f.ast.accept(MethodEnvironmentVisitor.new)
    end

    # Populate the inheritance information for the interfaces and
    # classes in each file.
    # FIXME(joey): Do we want to modify file.ast in-place? probably ok
    cycle_tracker = CycleTracker.new
    files = files.map {|file, namespace| resolve_inheritance(file, namespace, cycle_tracker)}
    # Check the hierarchy graph for any cycles.
    cycle_tracker.check()

    # Check the correctness of classes and interfaces.
    files = files.map {|file| check_correctness(file)}




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
    if parts.size > 0
      children[parts.first] = PackageNode.new(parts.first) if !children.has_key?(parts.first)
      c = children[parts.first]
      if !c.is_a?(PackageNode)
        raise NameResolutionStageError.new("type decl is prefix of existing package path")
      end
      c.add_child(parts[1..parts.size], node)
    elsif children.has_key?(node.name)
        raise NameResolutionStageError.new("name #{node.name} already exists in package (TODO produce package name)")
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

  def has_path?(path : String)
    return children.has_key?(path)
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

# `InterfaceResolutionVisitor` populates all extended interfaces within
# an `InterfaceDecl`.
class InterfaceResolutionVisitor < Visitor::GenericVisitor
  @namespace : ImportNamespace

  def initialize(@namespace : ImportNamespace)
  end

  def visit(node : AST::InterfaceDecl) : Nil
    # Populate each interface name reference.
    node.extensions.each do |interface|
      typ = @namespace.fetch(interface)
      if typ.nil?
        raise NameResolutionStageError.new("interface #{node.name} extends #{interface.name} but #{interface.name} was not found")
      elsif node.is_a?(AST::ClassDecl)
        raise NameResolutionStageError.new("interface #{node.name} extends #{interface.name} but #{interface.name} is a Class")
      end
      interface.ref = typ
    end

    # Check for repeated interfaces. We do this after resolution because
    # `java.lang.Clonable, Clonable` is a compile-time error.
    interfaces = Set(String).new
    node.extensions.each do |interface|
      if interfaces.includes?(interface.ref.as(AST::InterfaceDecl).qualified_name)
        raise NameResolutionStageError.new("interface #{node.name} extends #{interface.name} multiple times")
      end
      interfaces.add(interface.ref.as(AST::InterfaceDecl).qualified_name)
    end

    super
  end
end

# `ClassResolutionVisitor` populates the super class and all implemented
# interface references within a `ClassDecl`.
class ClassResolutionVisitor < Visitor::GenericVisitor
  @namespace : ImportNamespace

  def initialize(@namespace : ImportNamespace)
  end

  def visit(node : AST::ClassDecl) : Nil
    if node.super_class?
      typ = @namespace.fetch(node.super_class)
      if typ.nil?
        raise NameResolutionStageError.new("class #{node.name} extends #{node.super_class.name} but #{node.super_class.name} was not found")
      elsif node.super_class.name == node.name
        raise NameResolutionStageError.new("class #{node.name} cannot extend itself")
      elsif typ.is_a?(AST::InterfaceDecl)
        raise NameResolutionStageError.new("class #{node.name} extends #{node.super_class.name} but #{node.super_class.name} is an Interface")
      end
      node.super_class.ref = typ
    end

    node.interfaces.each do |interface|
      typ = @namespace.fetch(interface)
      if typ.nil?
        raise NameResolutionStageError.new("class #{node.name} implements #{interface.name} but #{interface.name} was not found")
      elsif typ.is_a?(AST::ClassDecl)
        raise NameResolutionStageError.new("class #{node.name} implements #{interface.name} but #{interface.name} is a Class")
      end
      interface.ref = typ
    end

    # Check for repeated interfaces. We do this after resolution because
    # `java.lang.Clonable, Clonable` is a compile-time error.
    interfaces = Set(String).new
    node.interfaces.each do |interface|
      if interfaces.includes?(interface.ref.as(AST::InterfaceDecl).qualified_name)
        raise NameResolutionStageError.new("class #{node.name} implements #{interface.name} multiple times")
      else
        STDERR.puts("class #{node.name} implements #{interface.name} for first time")
      end
      interfaces.add(interface.ref.as(AST::InterfaceDecl).qualified_name)
    end

    super
  end
end

class CycleTracker
  @vertices : Set(String)
  @edges : Hash(String, Array(String))

  def initialize
    @vertices = Set(String).new
    @edges = Hash(String, Array(String)).new
  end

  # Adds the directed dependancy edge.
  def add_edge(from : String, to : String)
    @vertices.add(from) if !@vertices.includes?(from)
    @edges[from] = Array(String).new if !@edges.has_key?(from)
    @edges[from].push(to)
  end

  # NOTE: visited_arr is tracking the call-stack for debugging purposes
  # only.
  def check_vertex(orig_v : String, verified, visited, visited_arr = Array(String).new)
    # If the graph stops here, add this verted as already traversed and
    # return.
    if !@edges.has_key?(orig_v)
      verified.add(orig_v)
      return
    end

    # Traverse down the dependancy tree.
    visited.add(orig_v)
    visited_arr.push(orig_v)
    @edges[orig_v].each do |c|
      # Check if the vertex has already been traversed to short-circuit.
      next if verified.includes?(c)
      # Check for a cycle if this has already been detected.
      if visited.includes?(c)
        visited_arr.push(c)
        msg = visited_arr.join(" -> ")
        raise NameResolutionStageError.new("cycle detected: #{msg}")
      end

      # Traverse deeper into the graph.
      check_vertex(c, verified, visited, visited_arr)
    end
    verified.add(orig_v)
    visited.delete(orig_v)
    visited_arr.pop
  end

  def check
    # _verified_ is the set of all nodes that have been visited previously
    # and do not need to be checekd again. This allows for
    # short-circuiting path traversal.
    verified = Set(String).new

    @vertices.each do |v|
      # _visited_ is the set of all nodes visited during iteration of a
      # single path.
      visited = Set(String).new
      check_vertex(v, verified, visited)
    end
  end
end

# `CycleVisitor` checks if there are interface cycles.
class CycleVisitor < Visitor::GenericVisitor
  @cycle_tracker : CycleTracker
  @namespace : ImportNamespace

  def initialize(@namespace : ImportNamespace, @cycle_tracker : CycleTracker)
  end

  def visit(node : AST::InterfaceDecl) : Nil
    node.extensions.each do |interface_name|
      interface = interface_name.ref.as(AST::InterfaceDecl)
      @cycle_tracker.add_edge(node.qualified_name, interface.qualified_name)
    end

    super
  end

  def visit(node : AST::ClassDecl) : Nil
    if node.super_class?
      soup_class = node.super_class.ref.as(AST::ClassDecl)
      @cycle_tracker.add_edge(node.qualified_name, soup_class.qualified_name)
    end

    super
  end
end

class ImportNamespace
  property simple_names : Hash(String, AST::TypeDecl)
  property qualified_names : Hash(String, AST::TypeDecl)

  def initialize(
    same_file : Array(Tuple(String, AST::TypeDecl)),
    single_type : Array(Tuple(String, AST::TypeDecl)),
    same_package : Array(Tuple(String, AST::TypeDecl)),
    on_demand : Array(Tuple(String, AST::TypeDecl)),
    system : Array(Tuple(String, AST::TypeDecl)),
    global : Array(Tuple(String, AST::TypeDecl)),
  )

    @simple_names = Hash(String, AST::TypeDecl).new
    # Add items to the namespace in this order. They will overload based
    # on the precedence rules.
    [system, on_demand, same_package, single_type, same_file].each do |scope|
      scope.each do |_, v|
        simple_names[v.name] = v
      end
    end

    @qualified_names = Hash(String, AST::TypeDecl).new
    global.each do |k, v|
      qualified_names[k] = v
    end
  end

  def fetch(node : AST::Name)
    if node.is_a?(AST::QualifiedName)
      return qualified_names.fetch(node.name, nil)
    else
      return simple_names.fetch(node.name, nil)
    end
  end
end

class MethodEnvironmentVisitor < Visitor::GenericVisitor
  @namespace : Array({name: String, decl: AST::Param | AST::VariableDecl}) = [] of NamedTuple(name: String, decl: AST::Param | AST::VariableDecl)
  @methodName : String = ""

  def addToNamespace(decl : AST::Param | AST::VariableDecl)
    @namespace.each do |n|
      if n[:name] == decl.name
        raise NameResolutionStageError.new("Duplicate declaration #{decl.name} in method #{@methodName}")
      end
    end
    @namespace.push({name: decl.name, decl: decl})
  end

  def visit(node : AST::MethodDecl) : Nil
    @methodName = node.name

    node.params.each do |p|
      addToNamespace(p)
    end

    visitStmts(node.body) if node.body?

    @namespace = [] of NamedTuple(name: String, decl: AST::Param | AST::VariableDecl)
  end

  def visitStmts(stmts : Array(AST::Stmt))
    return if stmts.size == 0

    stmt = stmts.first
    case stmt
    when AST::DeclStmt
      addToNamespace(stmt.var)
      stmt.var.accept(self)
      visitStmts(stmts[1..-1])
      @namespace.pop
    else
      stmt.accept(self)
      visitStmts(stmts[1..-1])
    end
  end

  def visit(node : AST::Block) : Nil
    visitStmts(node.children)
  end

  def visit(node : AST::ForStmt) : Nil
    visitStmts(node.children)
  end

  def visit(node : AST::SimpleName) : Nil
    return node if node.ref?
    @namespace.each do |n|
      if n[:name] == node.name
        node.ref = n[:decl]
      end
    end
  end
end

# `DuplicateFieldVisitor` checks the correctness of a classes
# declarations, also taking into account inheritance.
class DuplicateFieldVisitor < Visitor::GenericVisitor
  def initialize
  end

  def visit(node : AST::ClassDecl) : Nil
    field_set = Set(String).new
    node.fields.each do |f|
      field = f.as(AST::FieldDecl)
      # FIXME(joey): A field can be shadowed, so only check non-inherited fields.
      raise NameResolutionStageError.new("field \"#{field.decl.name}\" is redefined") if field_set.includes?(field.decl.name)
      field_set.add(field.decl.name)
    end

    super
  end
end

# `ClassTypResolutionVisitor` resolves the types in variable and
# field declarations.
class ClassTypResolutionVisitor < Visitor::GenericVisitor
  @namespace : ImportNamespace

  def initialize(@namespace : ImportNamespace)
  end

  def visit(node : AST::ClassTyp) : Nil
    typ = @namespace.fetch(node.name)
    if typ.nil?
      raise NameResolutionStageError.new("#{node.name.name} type was not found")
    end
    node.name.ref = typ

    super
  end
end
