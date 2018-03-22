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
  def initialize(@files : Array(SourceFile), @verbose : Bool, @use_stdlib : Bool)
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
        raise NameResolutionStageError.new("cannot single-type-import a package, only Class or Interfaces: violate file #{file.path} import #{import.path.name}")
      end
    end

    # Import java.lang.*, which is by default always imported at a
    # lower priority.
    import = AST::ImportDecl.new(AST::QualifiedName.new(["java", "lang"]), true)
    # Sources can be compiles without the stdlib, given a "--no-stdlib"
    # argument.
    if @use_stdlib
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
        same_package_imports = same_package_imports.map { |s, n| Tuple.new(s[1..s.size], n) }
      end
    end

    same_file_imports = file.ast.decls.map { |decl| Tuple.new(decl.name, decl) }

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
    file.ast = file.ast.accept(QualifiedNameDisambiguation.new(namespace))
    return file
  end

  def check_correctness(file, objectMethodDecls)
    file.ast.accept(DuplicateFieldVisitor.new)
    file.ast.accept(MethodAndCtorVisitor.new(objectMethodDecls))
    file.ast.accept(InheritanceCheckingVisitor.new)
  end

  def resolve
    exported_items = generate_exported_items(@files)

    # DEBUG INFO
    classes = exported_items.enumerate
    if @verbose
      STDERR.puts "=== EXPORTED ITEMS ==="
      STDERR.puts "#{classes.map(&.first).reject(&.starts_with? "java.").join("\n")}\n\n"
    end

    files = @files
    # Populate the imports for each file in-place.
    files.each { |f| f.import_namespace = populate_imports(f, exported_items) }

    # Populate the inheritance information for the interfaces and
    # classes in each file.
    cycle_tracker = CycleTracker.new
    files = files.map { |f| resolve_inheritance(f, f.import_namespace, cycle_tracker) }
    # Check the hierarchy graph for any cycles.
    cycle_tracker.check

    objectMethodDecls = [] of AST::MethodDecl
    # Grab the methods that were declared in the java.lang.Object Class
    if @use_stdlib
      object_name = AST::QualifiedName.new(["java", "lang", "Object"])
      files.each do |f|
        obj = f.import_namespace.fetch(object_name)
        objectMethodDecls = obj.methods unless obj.nil?
      end
    end

    # Check the correctness of classes and interfaces.
    files.each { |f| check_correctness(f, objectMethodDecls) }

    # Resolve all variables found in the files. This mutates the AST
    # in-place by resolving `Name.ref`.
    files.each { |f| f.ast.accept(MethodEnvironmentVisitor.new(f.import_namespace)) }

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

  def enumerate(prefix : String = "") : Array(Tuple(String, AST::TypeDecl))
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
    return children.values.flat_map(&.enumerate).map { |k, v| Tuple.new(prefix + k, v) } if @root

    return children.values.flat_map do |child|
      child.enumerate.map { |c_name, tree| Tuple.new(prefix + name + "." + c_name, tree) }
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

  property! current_class : AST::ClassDecl
  property! current_method_name : String
  property current_method_typ : Typing::Type?

  def initialize(
    same_file : Array(Tuple(String, AST::TypeDecl)),
    single_type : Array(Tuple(String, AST::TypeDecl)),
    same_package : Array(Tuple(String, AST::TypeDecl)),
    on_demand : Array(Tuple(String, AST::TypeDecl)),
    system : Array(Tuple(String, AST::TypeDecl)),
    global : Array(Tuple(String, AST::TypeDecl))
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

  def fetch(node : AST::Name) : AST::Node?
    if node.is_a?(AST::QualifiedName)
      return qualified_names.fetch(node.name, nil)
    else
      return simple_names.fetch(node.name, nil)
    end
  end
end

class DeclWrapper
  property! param : AST::Param
  property! decl_stmt : AST::VarDeclStmt
  property! field_decl : AST::FieldDecl

  def initialize(@param : AST::Param)
  end

  def initialize(@decl_stmt : AST::VarDeclStmt)
  end

  def initialize(@field_decl : AST::FieldDecl)
  end

  def unwrap : AST::Node
    case
    when param?      then return param
    when decl_stmt?  then return decl_stmt
    when field_decl? then return field_decl
    else                  raise Exception.new("unhandled case")
    end
  end
end

class MethodEnvironmentVisitor < Visitor::GenericVisitor
  @import_namespace : ImportNamespace

  # Namespace of the scope during AST traversal. It is populated as we
  # enter a function and encounter any `VarDeclStmt`.
  @namespace : Array({name: String, decl: DeclWrapper})

  # Field namespace of the scope during AST traversal. It is
  # pre-populated when we enter a `MethodDecl`.
  @field_namespace : Array({name: String, decl: DeclWrapper})

  # Name of the method currently being traversed.
  @current_method_name : String = ""

  property! type_decl_node : AST::TypeDecl

  # All type_decl instance fields that are accessible. The hash is
  # type_decl_name -> namespace.
  # Note that only classes have fields, as opposed to interfaces,
  # but it is convenient to implement this in terms of type decls
  # in general.
  @type_decl_instance_fields : Hash(String, Array({name: String, decl: DeclWrapper}))

  # All static instance fields that are accessible. The hash is
  # type_decl_name -> namespace.
  @type_decl_static_fields : Hash(String, Array({name: String, decl: DeclWrapper}))

  def initialize(@import_namespace : ImportNamespace)
    @namespace = [] of NamedTuple(name: String, decl: DeclWrapper)
    @field_namespace = [] of NamedTuple(name: String, decl: DeclWrapper)
    @type_decl_instance_fields = Hash(String, Array({name: String, decl: DeclWrapper})).new
    @type_decl_static_fields = Hash(String, Array({name: String, decl: DeclWrapper})).new
  end

  def add_to_namespace(decl : DeclWrapper)
    node = decl.unwrap
    if node.is_a?(AST::Param)
      name = node.name
    elsif node.is_a?(AST::VarDeclStmt)
      name = node.var.name
    elsif node.is_a?(AST::FieldDecl)
      name = node.var.name
    else
      raise Exception.new("unhandled case: #{node}")
    end
    @namespace.each do |n|
      if n[:name] == name
        raise NameResolutionStageError.new("Duplicate declaration #{name} in method #{@current_method_name}")
      end
    end
    @namespace.push({name: name, decl: decl})
  end

  def get_type_decl_instance_fields(node : AST::TypeDecl) : Array({name: String, decl: DeclWrapper})
    # TODO(joey): This depends on the order of fields matter so that
    # shadowing fields will be near the front so they resolve instead of
    # the shadowed fields. See `ClassDecl#fields` to see a TODO for
    # fixing this.
    # We use `namespace` to ensure the return value type matches the
    # function signature.
    namespace = [] of NamedTuple(name: String, decl: DeclWrapper)
    node.all_non_static_fields.each do |field|
      namespace.push({name: field.var.name, decl: DeclWrapper.new(field)})
    end
    return namespace
  end

  def get_type_decl_static_fields(node : AST::TypeDecl) : Array({name: String, decl: DeclWrapper})
    # TODO(joey): This depends on the order of fields matter so that
    # shadowing fields will be near the front so they resolve instead of
    # the shadowed fields. See `ClassDecl#fields` to see a TODO for
    # fixing this.
    # We use `namespace` to ensure the return value type matches the
    # function signature.
    namespace = [] of NamedTuple(name: String, decl: DeclWrapper)
    node.all_static_fields.each do |field|
      namespace.push({name: field.var.name, decl: DeclWrapper.new(field)})
    end
    return namespace
  end

  def visit(node : AST::PackageDecl | AST::ImportDecl) : Nil
    # Do not go down import or package declarations, as they may contain
    # a `SimpleName` that we do not resolve.
  end

  def visit(node : AST::TypeDecl) : Nil
    @type_decl_node = node
    @type_decl_instance_fields[node.name] = get_type_decl_instance_fields(node)
    @type_decl_static_fields[node.name] = get_type_decl_static_fields(node)
    methods = node.body.map(&.as?(AST::MethodDecl)).compact
    methods.each { |m| m.accept(self) }
    constructors = node.body.map(&.as?(AST::ConstructorDecl)).compact
    constructors.each { |m| m.accept(self) }
    fields = node.body.map(&.as?(AST::FieldDecl)).compact
    fields.each { |m| m.accept(self) }
  rescue ex : CompilerError
    ex.register("type_decl_name", node.name)
    raise ex
  end

  def visit(node : AST::FieldDecl) : Nil
    if node.has_mod?("static")
      @field_namespace = @type_decl_static_fields[type_decl_node.name]
    else
      @field_namespace = @type_decl_instance_fields[type_decl_node.name]
    end

    # We now use the assignde @field_namespace to validate name usage inside
    # the initializer, by calling super.
    super
  end

  def visit(node : AST::MethodDecl | AST::ConstructorDecl) : Nil
    @current_method_name = node.name
    # Set up the field namespace.
    if node.has_mod?("static")
      @field_namespace = @type_decl_static_fields[type_decl_node.name]
    else
      @field_namespace = @type_decl_instance_fields[type_decl_node.name]
    end

    # Start with an empty local namespace.
    @namespace = [] of NamedTuple(name: String, decl: DeclWrapper)

    # Add all of the method parameters to the namespace.
    node.params.each do |p|
      add_to_namespace(DeclWrapper.new(p))
    end

    visit_stmts(node.body) if node.is_a?(AST::ConstructorDecl) || node.body?
  rescue ex : CompilerError
    ex.register("method", node.name) if node.is_a?(AST::MethodDecl)
    ex.register("constructor", "") if node.is_a?(AST::ConstructorDecl)
    raise ex
  end

  def visit_stmts(stmts : Array(AST::Stmt))
    return if stmts.size == 0

    stmt = stmts.first
    case stmt
    when AST::VarDeclStmt
      add_to_namespace(DeclWrapper.new(stmt))
      stmt.var.accept(self)
      visit_stmts(stmts[1..-1])
      @namespace.pop
    else
      stmt.accept(self)
      visit_stmts(stmts[1..-1])
    end
  end

  def visit(node : AST::Block) : Nil
    visit_stmts(node.children)
  end

  def visit(node : AST::ForStmt) : Nil
    visit_stmts(node.children)
  end

  def visit(node : AST::QualifiedName) : Nil
    result = @import_namespace.fetch(node)
    if !result.nil?
      node.ref = result
      return
    end

    raise NameResolutionStageError.new("could not resolve qualified name {#{node.name}}")
  end

  def visit(node : AST::SimpleName) : Nil
    return node if node.ref?
    # The search order is:
    # 1) Local variables, including parameters.
    # 2) Fields.
    # 3) Classes, for resolving any static `FieldAccess`.
    @namespace.each do |n|
      if n[:name] == node.name
        node.ref = n[:decl].unwrap
        return
      end
    end
    @field_namespace.each do |n|
      if n[:name] == node.name
        node.ref = n[:decl].unwrap
        return
      end
    end

    # TODO(joey): If the name does not resolve to a local variable or
    # field in scope, search the import path for a Class. The parent
    # node must be a FieldAccess in this case.
    # TODO(joey): The above comment also applies for QualifiedName when
    # accessing static fields.
    result = @import_namespace.fetch(node)
    if !result.nil?
      node.ref = result
      return
    end

    raise NameResolutionStageError.new("could not find variable {#{node.name}}")
  end
end

# `DuplicateFieldVisitor` checks the correctness of a classes
# declarations, also taking into account inheritance.
class DuplicateFieldVisitor < Visitor::GenericVisitor
  def visit(node : AST::ClassDecl) : Nil
    field_set = Set(String).new
    node.fields.each do |f|
      field = f.as(AST::FieldDecl)
      raise NameResolutionStageError.new("field \"#{field.var.name}\" is redefined") if field_set.includes?(field.var.name)
      field_set.add(field.var.name)
    end

    super
  end
end

# `DuplicateFieldVisitor` checks the correctness of the method declarations
# and constructor declarations of classes and interfaces,
#  also taking into account inheritance.
class MethodAndCtorVisitor < Visitor::GenericVisitor
  def initialize(@objectMethodDecls : Array(AST::MethodDecl))
  end

  def visit(node : AST::TypeDecl) : Nil
    # Does a type decl itself declare any pair of methods which have the same
    # signature?
    methods = node.methods
    if methods.size > 1
      methods.each_with_index do |method, idx|
        if node.is_a?(AST::ClassDecl) && !node.has_mod?("abstract") && method.has_mod?("abstract")
          raise NameResolutionStageError.new("Abstract method \"#{method.name}\" within non-abstract class \"#{node.name}\"")
        end

        methods[(idx + 1)..-1].each do |other|
          if method.signature.equiv(other.signature)
            raise NameResolutionStageError.new("Duplicate method \"#{method.name}\" within type decl \"#{node.name}\"")
          end
        end
      end
    end

    # Does a type decl declare (implicitly or explicitly), any methods which
    # have the same signature but a different return type from any other method
    # in it's super-type-decl hierarchy?
    all_methods = node.all_methods(@objectMethodDecls)
    if all_methods.size > 1
      all_methods.each_with_index do |method, idx|
        all_methods[(idx + 1)..-1].each do |other|
          if method.signature.equiv(other.signature) && !method.equiv(other)
            raise NameResolutionStageError.new("Methods of name \"#{method.name}\" within type decl \"#{node.name}\" have non-matching return types or modifiers")
          end
        end
      end
    end

    super_methods = node.super_methods
    if super_methods.size > 0
      super_methods.each do |s_method|
        is_overridden_s_method? = true
        if s_method.has_mod?("abstract") && !node.has_mod?("abstract")
          is_overridden_s_method? = false
          super_methods.each do |other_s_method|
            if !other_s_method.has_mod?("abstract") && other_s_method.equiv(s_method)
              is_overridden_s_method? = true
            end
          end
        end

        methods.each do |method|
          if s_method.has_mod?("public") && method.has_mod?("protected") && method.equiv(s_method)
            raise NameResolutionStageError.new("Protected method \"#{method.name}\" in type decl \"#{node.name}\" is illegally overriding a public method")
          end

          if !method.has_mod?("abstract") && method.equiv(s_method)
            is_overridden_s_method? = true
          end
        end

        if !is_overridden_s_method?
          raise NameResolutionStageError.new("Abstract method \"#{s_method.name}\" is not defined concretely in \"#{node.name}\"")
        end
      end
    end

    all_super_methods = node.super_methods(@objectMethodDecls)
    if all_super_methods.size > 0
      all_super_methods.each do |s_method|
        methods.each do |method|
          if s_method.has_mod?("final") && method.signature.equiv(s_method.signature)
            raise NameResolutionStageError.new("Method \"#{method.name}\" in type decl \"#{node.name}\" is illegally overriding a final method")
          end
        end
      end
    end

    if node.is_a?(AST::ClassDecl)
      ctors = node.constructors
      ctors.each_with_index do |ctor, idx|
        ctors[(idx + 1)..-1].each do |other|
          if ctor.signature.equiv(other.signature)
            raise NameResolutionStageError.new("Class \"#{node.name}\" has duplicate Constructors")
          end
        end
      end
    end
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
  def initialize(@namespace : ImportNamespace)
  end

  # Ignore any `QualifiedName` found in `PackageDecl` or `ImportDecl`.
  # These remain unresolved, and are handled earlier in name resolution
  # for the `ImportNamespace`.
  def visit(node : AST::PackageDecl | AST::ImportDecl) : AST::Node
    return node
    # no super
  end

  def visit(node : AST::ExprRef) : AST::Node
    # If the qualified name was already resolved, then it (should be)
    # the child of a ClassTyp, which cannot be field accesses.
    # FIXME(joey): Once we add Parent references, we should assert this.
    name = node.name
    return node if name.ref? || !name.is_a?(AST::QualifiedName)
    return disambiguate(node.name)
  end

  def visit(node : AST::Variable) : AST::Node
    # If the Variable is just a Name, it might disambiguate to a series
    # of FieldAccess. Otherwise, it may be an array access that is
    # prefixed with a QualifiedName that needs to be disamguated.
    return super if !node.name? || node.name.is_a?(AST::SimpleName)
    return disambiguate(node.name)
  end

  def disambiguate(name : AST::Name) : AST::Node
    field_access = nil
    parts = name.parts

    # Go through the parts left to right to see if any prefix is a valid
    # type.
    parts.each_index do |i|
      path = parts[0..i].join(".")
      if i == 0
        class_name = AST::SimpleName.new(path)
      else
        class_name = AST::QualifiedName.new(parts[0..i])
      end
      if !@namespace.fetch(class_name).nil?
        # Do not populate the Name.ref immediately, because it may later
        # resolve to a local variable which will shadow the Type.
        # FIXME(joey): The same may apply to a package prefix. This is
        # currently only correct for types referred to directly and not
        # by package path.
        field_access = AST::ExprRef.new(class_name)
        parts = parts[i + 1..-1]
        break
      end
    end

    # Go through the parts from left to right and generate the field
    # accesses for the inner expression outwards. We do not iterate to
    # the last part as it is the literal for the outer-most
    # `ExprFieldAccess`.
    parts.each_index do |i|
      field_name = parts[i]
      # If this is the inner field, it begins with a variable access.
      if field_access.nil?
        field_access = AST::ExprRef.new(AST::SimpleName.new(parts[i]))
      else
        field_access = AST::ExprFieldAccess.new(field_access, field_name)
      end
    end
    return field_access.not_nil!
  end
end
