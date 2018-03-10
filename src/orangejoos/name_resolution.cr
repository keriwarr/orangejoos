require "./compiler_errors"
require "./ast"
require "./visitor"
require "./mutating_visitor"
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

    # Check for clashes of the namespace with any classes defined in the
    # file.
    # TODO(joey): Check that any decl in file.ast does not class with
    # anything in namespace (excluding the single exported type that
    # comes from this file).

    file.ast.accept(CycleVisitor.new(namespace, cycle_tracker))
    file.ast = file.ast.accept(QualifiedNameDisambiguation.new)
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

    # Populate the inheritance information for the interfaces and
    # classes in each file.
    cycle_tracker = CycleTracker.new
    files = files.map {|file, namespace| resolve_inheritance(file, namespace, cycle_tracker)}
    # Check the hierarchy graph for any cycles.
    cycle_tracker.check()

    # Check the correctness of classes and interfaces.
    files.each {|f| check_correctness(f)}

    # Resolve all variables found in the files. This mutates the AST
    # in-place by resolving `Name.ref`.
    files.each {|f| f.ast.accept(MethodEnvironmentVisitor.new)}

    return files
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
  # Namespace of the scope during AST traversal. It is populated as we
  # enter a function and encounter any `DeclStmt1.
  @namespace : Array({name: String, decl: (AST::Param | AST::VariableDecl)})
  # Field namespace of the scope during AST traversal. It is
  # pre-populated when we enter a `MethodDecl`.
  @field_namespace : Array({name: String, decl: (AST::Param | AST::VariableDecl)})
  # Name of the method currently being traversed.
  @current_method_name : String = ""

  @class_node : AST::ClassDecl?

  # All class instance fields that are accessible. The hash is
  # class_name -> namespace.
  @class_instance_fields : Hash(String, Array({name: String, decl: (AST::Param | AST::VariableDecl)}))

  # All static instance fields that are accessible. The hash is
  # class_name -> namespace.
  @class_static_fields :  Hash(String, Array({name: String, decl: (AST::Param | AST::VariableDecl)}))

  def initialize
    @namespace = [] of NamedTuple(name: String, decl: (AST::Param | AST::VariableDecl))
    @field_namespace = [] of NamedTuple(name: String, decl: (AST::Param | AST::VariableDecl))
    @class_instance_fields = Hash(String, Array({name: String, decl: (AST::Param | AST::VariableDecl)})).new
    @class_static_fields = Hash(String, Array({name: String, decl: (AST::Param | AST::VariableDecl)})).new
  end

  def addToNamespace(decl : AST::Param | AST::DeclStmt)
    if decl.is_a?(AST::Param)
      name = decl.name
    else
      name = decl.var.name
    end
    @namespace.each do |n|
      if n[:name] == name
        raise NameResolutionStageError.new("Duplicate declaration #{name} in method #{@current_method_name}")
      end
    end
    @namespace.push({name: name, decl: decl})
  end

  def get_class_instance_fields(node : AST::ClassDecl) : Array({name: String, decl: (AST::Param | AST::VariableDecl)})
    # TODO(joey): This depends on the order of fields matter so that
    # shadowing fields will be near the front so they resolve instead of
    # the shadowed fields. See `ClassDecl#fields` to see a TODO for
    # fixing this.
    # We use `namespace` to ensure the return value type matches the
    # function signature.
    namespace = [] of NamedTuple(name: String, decl: (AST::Param | AST::VariableDecl))
    node.non_static_fields.each {|field| namespace.push({name: field.var.name, decl: field.var})}
    return namespace
  end

  def get_class_static_fields(node : AST::ClassDecl) : Array({name: String, decl: (AST::Param | AST::VariableDecl)})
    # TODO(joey): This depends on the order of fields matter so that
    # shadowing fields will be near the front so they resolve instead of
    # the shadowed fields. See `ClassDecl#fields` to see a TODO for
    # fixing this.
    # We use `namespace` to ensure the return value type matches the
    # function signature.
    namespace = [] of NamedTuple(name: String, decl: (AST::Param | AST::VariableDecl))
    node.static_fields.each {|field| namespace.push({name: field.var.name, decl: field.var})}
    return namespace
  end

  def visit(node : AST::ClassDecl) : Nil
    @class_instance_fields[node.name] = get_class_instance_fields(node) if !@class_instance_fields.has_key?(node.name)
    @class_static_fields[node.name] = get_class_static_fields(node) if !@class_static_fields.has_key?(node.name)
    @class_node = node
    methods = node.body.map(&.as?(AST::MethodDecl)).compact
    methods.each {|m| m.accept(self)}
  end

  def visit(node : AST::MethodDecl) : Nil
    @current_method_name = node.name
    class_node = @class_node.not_nil!
    # Set up the field namespace.
    if node.has_mod?("static")
      @field_namespace = @class_static_fields[class_node.name]
    else
      @field_namespace = @class_instance_fields[class_node.name]
    end
    # Start with an empty local namespace.
    @namespace = [] of NamedTuple(name: String, decl: (AST::Param | AST::VariableDecl))

    # Add all of the method parameters to the namespace.
    node.params.each do |p|
      addToNamespace(p)
    end

    visitStmts(node.body) if node.body?
  end

  def visitStmts(stmts : Array(AST::Stmt))
    return if stmts.size == 0

    stmt = stmts.first
    case stmt
    when AST::DeclStmt
      addToNamespace(stmt)
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
    # The search order is:
    # 1) Local variables, including parameters.
    # 2) Fields.
    # 3) Classes, for resolving any static `FieldAccess`.
    @namespace.each do |n|
      if n[:name] == node.name
        node.ref = n[:decl]
        return
      end
    end
    @field_namespace.each do |n|
      if n[:name] == node.name
        node.ref = n[:decl]
        return
      end
    end

    # TODO(joey): If the name does not resolve to a local variable or
    # field in scope, search the import path for a Class. The parent
    # node must be a FieldAccess in this case.
    # TODO(joey): The above comment also applies for QualifiedName when
    # accessing static fields.
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
      # FIXME(joey): A field can be shadowed, so this check is removed. This should only check non-inherited fields.
      # raise NameResolutionStageError.new("field \"#{field.decl.name}\" is redefined") if field_set.includes?(field.decl.name)
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

  def visit(node : AST::CastExpr) : Nil
    if node.name?
      typ = @namespace.fetch(node.name)
      if typ.nil?
        raise NameResolutionStageError.new("#{node.name.name} type was not found")
      end
      node.name.ref = typ
    elsif node.expr?
      a = node.expr.as(AST::Name)
      typ = @namespace.fetch(a.name)
      if typ.nil?
        raise NameResolutionStageError.new("#{node.name.name} type was not found")
      end
      node.name.ref = typ
    end
  end
end


# `QualifiedNameDisambiguation` finds all amibigious `QualifiedName`
# which represent field accesses, and converts them to
# `ExprFieldAccess`. Currently, the only observed case of this is when a
# field access is only made on names. If any other part of an expression
# is part of it, it parses as a field access. For example:
# ```java
# x = hah.haha.Za.length; // Parses as QualifiedName.
# x = hah.Method().length; // Parses as FieldAccess.
# x = hah.Method().length.lala; // Parses as FieldAccess.
# x = hah.length; // Parses as QualifiedName.
# x = (new String()).length; // Parses as FieldAccess.
# ```
#
# This visitor must run before `MethodEnvironmentVisitor`, because this
# visitor may insert new `AST::ExprRef` that need to be resolved.
class QualifiedNameDisambiguation < Visitor::GenericMutatingVisitor
  def initialize
  end

  # Ignore any `QualifiedName` found in `PackageDecl` or `ImportDecl`.
  # These remain unresolved, and are handled earlier in name resolution
  # for the `ImportNamespace`.
  def visit(node : AST::PackageDecl | AST::ImportDecl) : AST::Node
    return node
  end

  def visit(node : AST::ExprRef) : AST::Node
    # If the qualified name was already resolved, then it (should be)
    # the child of a ReferenceTyp, which cannot be field accesses.
    # FIXME(joey): Once we add Parent references, we should assert this.
    name = node.name
    return node if name.ref? || !name.is_a?(AST::QualifiedName)

    field_access = nil
    parts = node.name.parts
    # Go through the parts from left to right and generate the field
    # accesses for the inner expression outwards. We do not iterate to
    # the last part as it is the literal for the outer-most
    # `ExprFieldAccess`.
    parts[0...parts.size-1].each_index do |i|
      field_name = AST::Literal.new(parts[i+1])
      # If this is the inner field, it begins with a variable access.
      if field_access.nil?
        var = AST::ExprRef.new(AST::SimpleName.new(parts[i]))
        field_access = AST::ExprFieldAccess.new(var, field_name)
      else
        field_access = AST::ExprFieldAccess.new(field_access, field_name)
      end
    end
    return field_access.not_nil!
  end
end
