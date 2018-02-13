# The AST is a simple and easy to manipulate representation of the
# source code.

INDENT = ->(depth : Int32) { "  " * depth }

module AST
  # Node is the root type of all AST elements.
  abstract class Node

    def pprint() : String
      pprint(0)
    end

    abstract def pprint(depth : Int32) : String
  end

  class Literal < Node
    getter val : String

    def initialize(@val : String)
    end

    def pprint(depth : Int32)
      return val
    end
  end

  class Keyword < Node
    getter val : String

    def initialize(@val : String)
    end

    def pprint(depth : Int32)
      return val
    end
  end

  class PackageDecl < Node
    property! path : Name

    def initialize(@path : Name)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}Package #{path.name}"
    end
  end

  class ImportDecl < Node
    property! path : Name
    # *on_demand* is whether the import is a wildcard import. An example
    # of that is:
    #
    #```java
    #   import java.util.*;
    #```
    #
    # This imports all the items within java.util on demand, as used.
    property on_demand : Bool = false

    def initialize(@path : Name)
    end

    def initialize(@path : Name, @on_demand : Bool)
    end

    def pprint(depth : Int32)
      on_demand_str = ""
      if on_demand
        on_demand_str = ".*"
      end
      indent = INDENT.call(depth)
      return "#{indent}Import #{path.name}#{on_demand_str}"
    end
  end

  class Modifier < Node
    property name : String

    def initialize(@name : String)
    end

    def pprint(depth : Int32)
      return name
    end
  end


  # TypeDecl is type declaration, either an InterfaceDecl or a
  # ClassDecl.
  # FIXME(joey): Interface and Class could maybe be squashed into one
  # node.
  abstract class TypeDecl < Node
    property! name : String
  end

  class ClassDecl < TypeDecl
    getter modifiers : Array(Modifier) = [] of Modifier
    property! super_class : Name
    getter interfaces : Array(Name) = [] of Name


    def initialize(@name : String, @modifiers : Array(Modifier), @super_class : Name | Nil, @interfaces : Array(Name))
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      super_str = ""
      if super_class?
        super_str = "#{super_class.name}"
      end
      interface_names = ""
      if interfaces.size > 0
        interface_names = interfaces.map {|i| i.name }.join(", ")
      end
      mods = modifiers.map {|i| i.name }.join(", ")
      return "#{indent}Class #{name}:
#{indent}  Modifiers: #{mods}
#{indent}  Super: #{super_str}
#{indent}  Interfaces: #{interface_names}"
    end
  end

  class InterfaceDecl < TypeDecl
    def initialize
      @name = "bye"
    end

    def pprint(depth : Int32)
      return "TODO"
    end
  end

  # Name represents a resolvable entity.
  abstract class Name < Node

    abstract def name : String
  end

  # A SimpleName refers to an entity within a context-sentivie
  # namespace.
  class SimpleName < Name
    getter name : String

    def initialize(@name : String)
    end

    def pprint(depth : Int32)
      return name
    end
  end

  # A QualifiedName is a name which has a qualified namespace.
  class QualifiedName < Name
    getter parts : Array(String)

    def initialize(@parts : Array(String))
    end

    def name
      parts.join(".")
    end

    def pprint(depth : Int32)
      return name
    end
  end

  # File is the top-level AST node, holding the top-level declarations
  # such as package, imports, and classes/interfaces.
  class File < Node
    property! package : PackageDecl
    property imports : Array(ImportDecl) = [] of ImportDecl
    property decls : Array(TypeDecl) = [] of TypeDecl

    def initialize(@package : PackageDecl | Nil, @imports : Array(ImportDecl), @decls : Array(TypeDecl))
    end

    def pprint(depth : Int32)
      pkg = ""
      if package?
        pkg = package.pprint(depth+1) + "\n"
      end
      imps = imports.map{ |i |i.pprint(depth+1) }.join("\n")
      if imports.size > 0
        imps += "\n"
      end
      decs = decls.map {|i| i.pprint(depth+1) }.join("\n")
      return "File:\n#{pkg}#{imps}#{decs}"
    end
  end
end
