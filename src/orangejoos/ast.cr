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

  abstract class Typ < Node
    property cardinality : Int32 = 0

    abstract def name : String
  end

  class PrimativeTyp < Typ
    @name : String

    def initialize(@name : String)
      @cardinality = 0
    end
    def initialize(@name : String, @cardinality : Int32)
    end

    def name
      arr_str = "[]" * cardinality
      return "#{@name}#{arr_str}"
    end

    def pprint(depth : Int32)
      return name
    end
  end

  class ReferenceTyp < Typ
    @name : Name

    def initialize(@name : Name)
      @cardinality = 0
    end
    def initialize(@name : Name, @cardinality : Int32)
    end

    def name
      arr_str = "[]" * cardinality
      return "#{@name.name}#{arr_str}"
    end

    def pprint(depth : Int32)
      return name
    end
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

  # A modifier. Bascially, just an identifier/string/keyword.
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
    getter modifiers : Array(Modifier) = [] of Modifier

    # FIXME(joey): This could easily be a mixin for types that have
    # modifiers.
    def has_mod(modifier : String)
      # FIXME(joey): This is terrible and we can use a set instead.
      modifiers.select {|m| m.name == modifier}.size > 0
    end
  end

  # A top-level class declaration.
  class ClassDecl < TypeDecl
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

  # A top-level interface declaration.
  class InterfaceDecl < TypeDecl
    getter extensions : Array(Name) = [] of Name
    getter body : Array(MemberDecl) = [] of MemberDecl

    def initialize(@name : String, @modifiers : Array(Modifier), @extensions : Array(Name), @body : Array(MemberDecl))
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      extensions_str = ""
      if extensions.size > 0
        extensions_str = extensions.map {|i| i.name }.join(", ")
      end
      mods = modifiers.map {|i| i.name }
      decls = body.map {|b| b.pprint(depth+2)}.join("\n")
      return "#{indent}Interface #{name}:
#{indent}  Modifiers: #{mods}
#{indent}  Extensions: #{extensions_str}
#{indent}  Decls:\n#{decls}"
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

  # Represents member declarations. This includes method and constant
  # declarations.
  abstract class MemberDecl < Node
    getter modifiers : Array(Modifier) = [] of Modifier
  end

  class FieldDecl < MemberDecl
    property typ : Typ
    property! decl : VariableDecl

    def initialize(@modifiers : Array(Modifier), @typ : Typ, @decl : VariableDecl | Nil)
    end

    def pprint(depth : Int32)
      mods = modifiers.map {|i| i.name }.join(",")
      indent = INDENT.call(depth)
      return "#{indent} field=#{decl.pprint(0)} type=#{typ.name} mods=#{mods}"
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

  # Represents an expressio nwhich is a variable declaration.
  # TOOD(joey): Maybe this just needs to be an expr?
  class VarInit < Node
    def initialize
    end

    def pprint(depth : Int32)
      return "VarInit: TODO"
    end
  end

  # Represents a variable declaration: a name, a cardinality and an
  # optional initialization.
  class VariableDecl < Node
    property name : String
    property cardinality : Int32 = 0
    property init : VarInit

    def initialize(@name : String, @cardinality : Int32, @init : VarInit)
    end

    def pprint(depth : Int32)
      return "VarDecl: #{name} card=#{cardinality} init={#{init.pprint(0)}}"
    end
  end

  class Param < Node
    property name : String
    property typ : Typ

    def initialize(@name : String, @typ : Typ)
    end

    def pprint(depth : Int32)
      return "Param: TODO"
    end
  end

  class Block < Node
    def initialize
    end

    def pprint(depth : Int32)
      return "Block: TODO"
    end
  end

  class MethodDecl < MemberDecl
    property name : String
    property typ : Typ
    property modifiers : Array(Modifier) = [] of Modifier
    property params : Array(Param) = [] of Param
    property! body : Block

    def initialize(@name : String, @typ : Typ, @modifiers : Array(Modifier), @params : Array(Param), @body : Block | Nil)
    end

    def has_mod(modifier : String)
      # FIXME(joey): This is terrible and we can use a set instead.
      modifiers.select {|m| m.name == modifier}.size > 0
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      mods = modifiers.map {|i| i.name }
      return "#{indent}method #{name} #{typ.pprint(0)} #{mods} #{params}"
    end
  end
end
