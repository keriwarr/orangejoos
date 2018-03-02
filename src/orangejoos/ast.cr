# The AST is a simple and easy to manipulate representation of the
# source code.

# TODO(joey): A great way to represent names and their resolved types
# would be adding functionality to `Name` to have a settable referenced
# type. That way each `Name` gets evaluated and a reference is added in
# that AST node, without having to add extra machinery in the parent
# node.


require "./visitor.cr"

INDENT = ->(depth : Int32) { "  " * depth }

# `AST` is the abstract syntax tree for Joos1W. There are 3 primary
# categories of nodes:
# - _Statements_, which are all decendants of `Stmt`
# - _Expressions_, decendants of `Expr`.
# - _Declarations_. This includes top-level declarations `ClassDecl` and
#   `InterfaceDecl`.
#
# There are a few other noteworthy AST nodes such as `Typ`, `Name`, and
# `Const`.
module AST

  # `Node` is the root type of all `AST` elements.
  abstract class Node

    # `pprint` returns a pretty string representation of the node, for
    # debug purposes.
    def pprint() : String
      pprint(0)
    end

    # Internal function: `pprint` with a depth, which represents the
    # indentation level of depth the node belongs in.
    abstract def pprint(depth : Int32) : String
    def accept(v : Visitor::Visitor) : Node
      v.descend
      result = v.visit(self)
      v.ascend
      return result
    end
  end

  # `Stmt` are AST nodes which appear in the body of methods and can be
  # executed. Not all `Stmt` return values.
  abstract class Stmt < Node

    abstract def children : Array(Stmt)

    # TODO(joey): This was an attempt to make a traversal function for
    # `Stmt` trees in a rather general manner. It is not actually used.
    def traverse(map : Stmt -> Tuple(Object, Boolean), reduce : Array(Object) -> Object)
      results = [] of Object

      result, cont = map(self)
      if !cont
        return result
      end

      results.push(result)

      self.children.each do |c|
        result, cont = c.traverse(map, reduce)
        if !cont
          return {result, cont}
        end
        results.push(result)
      end

      return {reduce(results.compact), false}
    end
  end

  # `Expr` are parts of the code which return a value. They are a subset
  # of `Stmt`, meaning they are also traversable and are only
  # distinguished by the property of returning values.
  abstract class Expr < Stmt
    def initialize
    end
  end

  # Typ represents all types.
  abstract class Typ < Expr
    # The _cardinality_ array of the type. If the _cardinality_ is `0`, the
    # type is not an array. For example, the following type has a
    # cardinality of 2:
    # ```java
    # int[][]
    # ```
    property cardinality : Int32 = 0

    # The _name_ of the type being represented by the AST node.
    abstract def name_str : String

    def children
      [] of Expr
    end
  end

  # `PrimitiveTyp` represents built-in types. This includes the types:
  #
  # - _boolean_
  # - _byte_
  # - _short_
  # - _int_
  # - _char_
  #
  # `PrimitiveTyp` also contains the _cardinality_ of the represented
  # type.
  class PrimitiveTyp < Typ
    @name : String

    def initialize(@name : String)
      @cardinality = 0
    end

    def initialize(@name : String, @cardinality : Int32)
    end

    # The _name_ of the type represented by the AST node.
    def name_str
      arr_str = "[]" * cardinality
      return "#{@name}#{arr_str}"
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{name_str}"
    end
  end

  # `ReferenceType` represents user-defined Class and Interface types,
  # including the cardinality.
  class ReferenceTyp < Typ
    property name : Name

    def initialize(@name : Name)
      @cardinality = 0
    end
    def initialize(@name : Name, @cardinality : Int32)
    end

    def name_str
      arr_str = "[]" * cardinality
      return "#{@name.name}#{arr_str}"
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{name_str}"
    end
  end

  # FIXME(joey): The literal is instead used for identifiers, such as class
  # names, method names, and argument names. This should be refactored.
  class Literal < Node
    getter val : String

    def initialize(@val : String)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{val}"
    end
  end

  # FIXME(joey): Not quite sure where keywords appear in the parse tree,
  # or if it even matters. These will appear in the parse tree in place
  # of words such as "if", "else", etc. but should not be used in the
  # AST.
  class Keyword < Node
    getter val : String

    def initialize(@val : String)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{val}"
    end
  end

  # `PackageDecl` represents the package declaration at the top of the
  # file. For example:
  #
  # ```java
  # package com.java.util;
  # ```
  #
  # TODO(joey): This could probably be squashed into the File node due
  # to this only containing a Name.
  class PackageDecl < Node
    property! path : Name

    def initialize(@path : Name)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}Package #{path.name}"
    end
  end

  # _ImportDecl_ represents an import declaration at the top of the
  # file. For example:
  #
  # ```java
  # import com.java.util.Vector;
  # ```
  #
  # or, for importing all of the contents of a package:
  #
  # ```java
  # import com.java.util.*;
  # ```
  class ImportDecl < Node
    # The _path_ the import declaration is importing.
    property path : Name

    # _on_demand_ is whether the import is a wildcard import. An example
    # of that is:
    #
    # ```java
    # import java.util.*;
    # ```
    #
    # This imports all the items within java.util on demand, as used.
    property on_demand : Bool = false

    def initialize(@path : Name)
    end

    def initialize(@path : Name, @on_demand : Bool)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      on_demand_str = ""
      if on_demand
        on_demand_str = ".*"
      end
      return "#{indent}Import #{path.name}#{on_demand_str}"
    end
  end

  # `Modifier` represents modifier keywords. This includes:
  # - public
  # - protected
  # - static
  # - abstract
  # - final
  # - native
  class Modifier < Node
    property name : String

    def initialize(@name : String)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{name}"
    end
  end


  # `TypeDecl` is type declaration, either a `InterfaceDecl` or a
  # `ClassDecl`.
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

  # `ClassDecl` is a top-level declaration for classes. Classes contain
  # a name, a super class, implemented interfaces, and a list of field
  # and method declarations.
  class ClassDecl < TypeDecl
    property! super_class : Name
    getter interfaces : Array(Name) = [] of Name
    getter body : Array(MemberDecl) = [] of MemberDecl

    def initialize(@name : String, @modifiers : Array(Modifier), @super_class : Name | Nil, @interfaces : Array(Name), @body : Array(MemberDecl))
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
      decls = body.map {|b| b.pprint(depth+2)}.join("\n")
      return (
        "#{indent}Class #{name}:\n" \
        "#{indent}  Modifiers: #{mods}\n" \
        "#{indent}  Super: #{super_str}\n" \
        "#{indent}  Interfaces: #{interface_names}\n" \
        "#{indent}  Decls:\n#{decls}"
      )
    end
  end

  # `InterfaceDecl` is a top-level declaration for interfaces.
  # Interfaces contain a name, extended interfaces, method declarations.
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
      return (
        "#{indent}Interface #{name}:\n" \
        "#{indent}  Modifiers: #{mods}\n" \
        "#{indent}  Extensions: #{extensions_str}\n" \
        "#{indent}  Decls:\n#{decls}"
      )
    end
  end

  # `Name` represents a resolvable entity. This includes package names,
  # which are `QualifiedName`, such as:
  # ```java
  # com.java.util.Vector
  # ```
  #
  # as well as type names, which are `SimpleName`:
  # ```java
  # Vector
  # ```
  abstract class Name < Node

    abstract def name : String
    abstract def parts : Array(String)
  end

  # `SimpleName` refers to a resolvable entity, such as local
  # declarations.
  class SimpleName < Name
    getter name : String

    def initialize(@name : String)
    end

    def parts
      [name] of String
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{name}"
    end
  end

  # `QualifiedName` is a name which has a qualified namespace, such as a
  # package name or an item in another scope.
  class QualifiedName < Name
    getter parts : Array(String)

    def initialize(@parts : Array(String))
    end

    def name
      parts.join(".")
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{name}"
    end
  end

  # `MemberDecl` represents declarations which are members of an object
  # (either `InterfaceDecl` or `ClassDecl`).
  abstract class MemberDecl < Node
    getter modifiers : Array(Modifier) = [] of Modifier

    def has_mod(modifier : String)
      # FIXME(joey): This is terrible and we can use a set instead.
      modifiers.select {|m| m.name == modifier}.size > 0
    end
  end

  # `FieldDecl` represents a field declaration in a class. For example:
  # ```java
  # public class A {
  #   private int b;
  # }
  # ```
  class FieldDecl < MemberDecl
    property typ : Typ
    property decl : VariableDecl

    def initialize(@modifiers : Array(Modifier), @typ : Typ, @decl : VariableDecl)
    end

    def pprint(depth : Int32)
      mods = modifiers.map {|i| i.name }.join(",")
      indent = INDENT.call(depth)
      return "#{indent}field #{decl.pprint(0)} type=#{typ.name_str} mods=#{mods}"
    end
  end

  # `File` is the root AST node. It holds all of the files top-level
  # declarations such the package (`PackageDecl`), imports
  # (`ImportDecl`) and classes/interfaces (`MemberDecl`).
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

    def decl?(name)
      decls.map(&.name).map(&.==(name)).size > 0
    end

    def decl(name) : TypeDecl
      results = decls.select {|decl| decl.name == name}
      if results.size > 1
        raise Exception.new("more than 1 decl, got: #{results}")
      end
      return results.first
    end
  end

  # `Param` represents a parameter definition in a method signature. It
  # includes the _name_ and _typ_ of the paramter.
  class Param < Node
    property name : String
    property typ : Typ

    def initialize(@name : String, @typ : Typ)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}<Param #{name} #{typ.pprint(0)}>"
    end
  end

  # `Block` is a group of `Stmt`. It is used to isolate the scope of the
  # contained `Stmt`. A block is created by the following code:
  # ```java
  # int x;
  # { // Beginning of the block.
  #   int y;
  # }
  # ```
  class Block < Stmt
    property stmts : Array(Stmt) = [] of Stmt

    def initialize(@stmts : Array(Stmt))
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      stmts_str = (stmts.map {|s| s.pprint(depth+1)}).join("\n")
      return "#{indent}Block:\n#{stmts_str}"
    end

    def children
      stmts
    end
  end

  # `ForStmt` is a for-loop block. It may have an init `Stmt`, a
  # comparison `Expr`, and a update `Stmt`. It will always have a `Stmt`
  # block. A for-loop is created by the following code:
  # ```java
  # for ( /*init*/ ; /*expr*/; /*update*/) {
  #   /*stmt*/
  # }
  # ```
  class ForStmt < Stmt
    property! init : Stmt
    property! expr : Expr
    property! update : Stmt
    property body : Stmt

    def initialize(@init : Stmt | Nil, @expr : Expr | Nil, @update : Stmt | Nil, @body : Stmt)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return (
        "#{indent}For:\n" \
        "#{indent}  Init: #{@init.try &.pprint}\n" \
        "#{indent}  Expr: #{@expr.try &.pprint}\n" \
        "#{indent}  Update: #{@update.try &.pprint}\n" \
        "#{indent}  Body:\n#{body.pprint(depth+2)}"
      )
    end

    def children
      [init, expr.as(Stmt), update, body] of Stmt
    end
  end

  # `WhileStmt` is a while-loop block. It has a comparison `Expr` and a
  # `Stmt` block. A while-loop is created by the following code:
  # ```java
  # while ( /*expr*/ ) {
  #   /*stmt*/
  # }
  # ```
  class WhileStmt < Stmt
    property expr : Expr
    property body : Stmt

    def initialize(@expr : Expr, @body : Stmt)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return (
        "#{indent}While:\n" \
        "#{indent}  Expr: #{expr.pprint}\n" \
        "#{indent}  Body:\n#{body.pprint(depth+2)}"
      )
    end

    def children
      [init, expr.as(Stmt), update, body] of Stmt
    end
  end

  # `IfStmt` is an if-block control flow. It has a comparison `Expr`, a
  # `Stmt` to execute if the comparison is true, and optionally a `Stmt
  # to execute if it is false. An if-block is created by the following
  # code:
  # ```java
  # if (/* expr */) {
  #   /* if_body */
  # } else {
  #   /* else_body */
  # }
  # ```
  class IfStmt < Stmt
    property expr : Expr
    property if_body : Stmt
    property! else_body : Stmt

    def initialize(@expr : Expr, @if_body : Stmt, @else_body : Stmt | Nil)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return (
        "#{indent} If:\n" \
        "#{indent}  Expr: #{expr.pprint}\n" \
        "#{indent}  IfBody:\n#{if_body.pprint(depth+1)}"
        "#{indent}  ElseBody:\n#{@else_body.try &.pprint(depth+2)}"
      )
    end

    def children
      if else_body?
        [expr.as(Stmt), if_body, else_body] of Stmt
      else
        [expr.as(Stmt), if_body] of Stmt
      end
    end
  end

  # `ExprOp` is an operator expression. Each expression has an operator
  # (`op`) and any number of `operands`. They generically any type of
  # operator, including unary and binary.
  # TODO: can we make operands into type `Expr | NamedTuple(lhs: Expr, rhs: Expr)` ?
  class ExprOp < Expr
    property op : String
    property operands : Array(Expr) = [] of Expr

    def initialize(@op : String, *ops)
      ops.each do |operand|
        if operand.is_a?(Expr)
          @operands.push(operand)
        else
          raise Exception.new("unexpected type, got operand: #{operand.inspect}")
        end
      end
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      if operands.size == 1
        first_operand_str = "#{op} #{operands[0].pprint(0)}"
        rest_operands_str = ""
      else
        first_operand_str = "#{operands[0].pprint(0)} #{op} "
        rest_operands_str = (operands.skip(1).map {|o| o.pprint(0)}).join(" ")
      end
      return "#{indent}(#{first_operand_str}#{rest_operands_str})"
    end

    def children
      return operands
    end
  end

  # `ExprClassInit` is an expression that is initializing a new class.
  # It has a `name` of the class being initialized and the `args` for
  # the constructor. For example:
  # ```java
  # new A()
  # ```
  class ExprClassInit < Expr
    property name : Name
    property args : Array(Expr) = [] of Expr

    def initialize(@name : Name, @args : Array(Expr))
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "ExprClassInit: TODO(keri)"
    end

    def children
      return args
    end
  end

  # `ExprFieldAccess` represents a instance field access.
  class ExprFieldAccess < Expr
    property obj : Expr
    property field : Literal

    def initialize(@obj : Expr, @field : Literal)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "ExprFieldAccess: TODO(keri)"
    end

    def children
      return [obj]
    end
  end

  # `ExprArrayAccess` represents an array access.
  class ExprArrayAccess < Expr
    # FIXME(joey): Rather hacky way to support these two ways to write
    # an array access, an expr that returns an array or by directly
    # using an identifier name.
    property! arr_expr : Expr
    property! arr_name : Name
    property index : Expr

    def initialize(@arr_expr : Expr, @index : Expr)
    end

    def initialize(@arr_name : Name, @index : Expr)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "ExprArrayAccess: TODO(keri)"
    end

    def children
      if arr_expr?
        return [arr_expr, index]
      else
        return [index]
      end
    end
  end

  # `ExprArrayCreation` represents an array creation.
  class ExprArrayCreation < Expr
    # FIXME(joey): Specialize the node type used here. Maybe if we
    # create a Type interface that multiple AST nodes can implement,
    # such as Name (or Class/Interface) and PrimativTyp.
    property arr : Node
    property dim : Expr

    def initialize(@arr : Node, @dim : Expr)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "ExprArrayCreation: TODO(keri)"
    end

    def children
      return [arr, dim]
    end
  end

  # `ExprThis` represents the `this` expression, which will return the
  # currently scoped `this` instance.
  class ExprThis < Expr
    def initialize
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}this"
    end

    def children
      [] of Expr
    end
  end

  # `ExprRef` represents referenced values, such as fields or classes.
  # For example, the `x` in `1 + x` is an ExprRef:
  # ```java
  # int x;
  # 1 + x;
  # ```
  #
  class ExprRef < Expr
    property name : Name

    def initialize(@name : Name)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{name.pprint(0)}"
    end

    def children
      [] of Expr
    end
  end

  # `MethodInvoc` represents a method invocation.
  # For example:
  # ```java
  # A(1, 'a')
  # (new B(1)).meth()
  # ```
  #
  class MethodInvoc < Expr
    property! expr : Expr
    property name : Name
    property args : Array(Expr)

    def initialize(@expr : Expr | Nil, @name : Name, @args : Array(Expr))
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}MethodInvoc of #{expr.try &.pprint(0)} name=#{name.pprint(0)} args=#{args.map &.pprint(0)}"
    end

    def children
      if expr?
        [expr] of Expr + args
      else
        args
      end
    end
  end

  # `Const` are expressions with a constant value.
  abstract class Const < Expr
    def children
      [] of Expr
    end
  end

  class ConstInteger < Const
    # FIXME(joey): Make this a proper int val.
    property val : String

    def initialize(@val : String)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{val}"
    end
  end

  class ConstBool < Const
    # FIXME(joey): Make this a proper bool val.
    property val : String

    def initialize(@val : String)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}#{val}"
    end
  end

  class ConstChar < Const
    # FIXME(joey): Make this a proper char val.
    property val : String

    def initialize(@val : String)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}'#{val}'"
    end

  end

  class ConstString < Const
    property val : String

    def initialize(@val : String)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}\"#{val}\""
    end
  end

  class ConstNull < Const
    def initialize
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      return "#{indent}null"
    end
  end


  # `VariableDecl` represents variable declarations, including `name`,
  # `cardinality` and the expression to initialize the value of the
  # variable to (`init`).
  class VariableDecl < Node
    property name : String
    property! init : Expr

    def initialize(@name : String,@init : Expr | Nil)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      init_str = init? ? init.pprint(0) : "<no init>"
      return "#{indent}VarDecl: #{name} init={#{init_str}}"
    end
  end

  # `DeclStmt` is a variable declaration statement. It wraps
  # `VariableDecl` to also include information about the `Typ` of the
  # `VariableDecl`.
  #
  # TODO(joey): Squash `VariableDecl` into this node. This will need to
  # be squashed into both the `FieldDecl` and `DeclStmt`. The only
  # difference is `FieldDecl` includes modifiers.
  class DeclStmt < Stmt
    property typ : AST::Typ
    property var : AST::VariableDecl

    def initialize(@typ : AST::Typ, @var : AST::VariableDecl)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      #TODO(joey): make printing better when you do the above squash
      return "#{indent}#{typ.pprint(0)} #{var.pprint(0)}"
    end

    def children
      if var.init.nil?
        return [] of Stmt
      else
        return [var.init]
      end
    end
  end

  # `MethodDecl` is a method declaration. It includes `name`, `typ,`
  # `modifiers`, `params` for the method signature, and the `body`.
  class MethodDecl < MemberDecl
    property name : String
    property typ : Typ
    property modifiers : Array(Modifier) = [] of Modifier
    property params : Array(Param) = [] of Param
    property! body : Array(Stmt) | Nil

    def initialize(@name : String, @typ : Typ, @modifiers : Array(Modifier), @params : Array(Param), @body : Array(Stmt))
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      mods = modifiers.map {|i| i.name }
      p = params.map {|i| i.pprint(0)}
      if body?
        body_str = (body.map {|b| b.pprint(depth+1)}).join("\n")
      else
        body_str = "<no body>"
      end
      return "#{indent}method #{name} #{typ.pprint(0)} #{mods} #{p}\n#{body_str}"
    end
  end


  # `ConstructorDecl` is a specia lmethod declaration. It includes
  # `name`, `modifiers`, `params` for the method signature, and the
  # `body`. FIXME(joey): This can probably be squashed into `MethodDecl`
  # with a flag denoting it's a constructor with no type.
  class ConstructorDecl < MemberDecl
    property name : SimpleName
    property modifiers : Array(Modifier) = [] of Modifier
    property params : Array(Param) = [] of Param
    property body : Array(Stmt) = [] of Stmt

    def initialize(@name : SimpleName, @modifiers : Array(Modifier), @params : Array(Param), @body : Array(Stmt))
    end

    def has_mod(modifier : SimpleName)
      # FIXME(joey): This is terrible and we can use a set instead.
      modifiers.select {|m| m.name == modifier}.size > 0
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      mods = modifiers.map {|i| i.name }
      p = params.map {|i| i.pprint(0)}
      return "#{indent}constructor #{name.pprint(0)} #{mods} #{p}"
    end
  end

  class ReturnStmt < Stmt
    property! expr : Expr | Nil

    def initialize(@expr : Expr | Nil)
    end

    def pprint(depth : Int32)
      indent = INDENT.call(depth)
      expr_str = ""
      if expr?
        expr_str = " #{expr.pprint(0)}"
      end
      return "#{indent}return#{expr_str}"
    end

    def children
      if expr.nil?
        return [] of Expr
      else
        return [expr]
      end
    end
  end
end
