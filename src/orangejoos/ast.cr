# The AST is a simple and easy to manipulate representation of the
# source code.

# TODO(joey): A great way to represent names and their resolved types
# would be adding functionality to `Name` to have a settable referenced
# type. That way each `Name` gets evaluated and a reference is added in
# that AST node, without having to add extra machinery in the parent
# node.


require "./visitor"
require "./typing"

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

  module Modifiers
    getter modifiers : Set(String) = Set(String).new

    def modifiers=(mods : Array(Modifier))
      @modifiers = Set(String).new(mods.map(&.name))
    end

    # FIXME(joey): For maximum correctness, the parameter type should be
    # an ENUM of all correct modifiers.
    def has_mod?(modifier : String)
      modifiers.includes?(modifier)
    end
  end

  # `Node` is the root type of all `AST` elements.
  abstract class Node
    def accept(v : Visitor::Visitor) : Nil
      v.descend
      v.visit(self)
      v.ascend
    end

    # Implementations of this method should return all properties of this node which
    # are themselves Nodes.
    abstract def ast_children : Array(Node)
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
    include Typing

    def initialize
    end

    # TODO(joey): Implement for each type and remove this stubbed method.
    private def resolve_type
      raise Exception.new("Unimplemented")
      return ExprTyp.new("huzza")
    end

    abstract def to_s : String
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

    def to_s : String
      name_str
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

    def ast_children : Array(Node)
      [] of Node
    end
  end

  # `ReferenceType` represents user-defined Class and Interface types,
  # including the cardinality.
  class ReferenceTyp < Typ
    property name : Name
    property cardinality : Int32

    def initialize(@name : Name)
      @cardinality = 0
    end
    def initialize(@name : Name, @cardinality : Int32)
    end

    def name_str
      arr_str = "[]" * cardinality
      return "#{@name.name}#{arr_str}"
    end

    def ast_children : Array(Node)
      [name.as(Node)]
    end
  end

  # FIXME(joey): The literal is instead used for identifiers, such as class
  # names, method names, and argument names. This should be refactored.
  class Literal < Node
    getter val : String

    def initialize(@val : String)
    end

    def to_s : String
      return val
    end

    def ast_children : Array(Node)
      [] of Node
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

    def ast_children : Array(Node)
      [] of Node
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

    def ast_children : Array(Node)
      ([path?.as?(Node)] of Node?).compact
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

    def ast_children : Array(Node)
      [path.as(Node)]
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

    def ast_children : Array(Node)
      [] of Node
    end
  end


  # `TypeDecl` is type declaration, either a `InterfaceDecl` or a
  # `ClassDecl`.
  # FIXME(joey): Interface and Class could maybe be squashed into one
  # node.
  abstract class TypeDecl < Node
    include Modifiers

    property! name : String
    property! qualified_name : String
  end

  # `ClassDecl` is a top-level declaration for classes. Classes contain
  # a name, a super class, implemented interfaces, and a list of field
  # and method declarations.
  class ClassDecl < TypeDecl
    property! super_class : Name
    getter interfaces : Array(Name) = [] of Name
    getter body : Array(MemberDecl) = [] of MemberDecl

    def initialize(@name : String, modifiers : Array(Modifier), @super_class : Name | Nil, @interfaces : Array(Name), @body : Array(MemberDecl))
      self.modifiers = modifiers
    end

    def fields : Array(FieldDecl)
      visible_fields = body.select(&.is_a?(FieldDecl))
      visible_fields += super_class.ref.as(ClassDecl).fields if super_class?
      return visible_fields.map(&.as(FieldDecl))
    end

    def non_static_fields : Array(FieldDecl)
      fields.reject &.has_mod?("static")
    end

    def static_fields : Array(FieldDecl)
      fields.select &.has_mod?("static")
    end

    def ast_children : Array(Node)
      [super_class?.as?(Node), interfaces.map &.as(Node), body.map &.as(Node)].flatten.compact
    end
  end

  # `InterfaceDecl` is a top-level declaration for interfaces.
  # Interfaces contain a name, extended interfaces, method declarations.
  class InterfaceDecl < TypeDecl
    getter extensions : Array(Name) = [] of Name
    getter body : Array(MemberDecl) = [] of MemberDecl

    def initialize(@name : String, modifiers : Array(Modifier), @extensions : Array(Name), @body : Array(MemberDecl))
      self.modifiers = modifiers
    end

    def ast_children : Array(Node)
      [extensions.map &.as(Node), body.map &.as(Node)].flatten
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
    property! ref : Node

    abstract def name : String
    abstract def parts : Array(String)

    def ast_children : Array(Node)
      [] of Node
    end
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
  end

  # `MemberDecl` represents declarations which are members of an object
  # (either `InterfaceDecl` or `ClassDecl`).
  abstract class MemberDecl < Node
    include Modifiers
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

    def initialize(modifiers : Array(Modifier), @typ : Typ, @decl : VariableDecl)
      self.modifiers = modifiers
    end

    def ast_children : Array(Node)
      [typ.as(Node), decl.as(Node)]
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

    def decl?(name)
      decls.map(&.name).select(&.==(name)).size > 0
    end

    def decl(name) : TypeDecl
      results = decls.select {|decl| decl.name == name}
      if results.size > 1
        raise Exception.new("more than 1 decl, got: #{results}")
      end
      return results.first
    end

    def ast_children : Array(Node)
      [package?.as?(Node), imports.map &.as(Node), decls.map &.as(Node)].flatten.compact
    end
  end

  # `Param` represents a parameter definition in a method signature. It
  # includes the _name_ and _typ_ of the paramter.
  class Param < Node
    property name : String
    property typ : Typ

    def initialize(@name : String, @typ : Typ)
    end

    def to_s : String
      "#{name} : #{typ.to_s}"
    end

    def ast_children : Array(Node)
      [typ.as(Node)]
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

    def children
      stmts
    end

    def ast_children : Array(Node)
      stmts.map &.as(Node)
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

    def children
      ([init?, expr?.as?(Stmt), update?, body] of Stmt | Nil).compact
    end

    def ast_children : Array(Node)
      [init?.as?(Node), expr?.as?(Node), update?.as?(Node), body.as(Node)].compact
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

    def children
      [init, expr.as(Stmt), update, body] of Stmt
    end

    def ast_children : Array(Node)
      [expr.as(Node), body.as(Node)]
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

    def children
      if else_body?
        [expr.as(Stmt), if_body, else_body] of Stmt
      else
        [expr.as(Stmt), if_body] of Stmt
      end
    end

    def ast_children : Array(Node)
      [expr.as(Node), if_body.as(Node), else_body?.as?(Node)].compact
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
        # FIXME: (keri) this is gross
        if operand.is_a?(Expr)
          @operands.push(operand)
        else
          raise Exception.new("unexpected type, got operand: #{operand.inspect}")
        end
      end
    end

    def to_s : String
      if operands.size == 1
        first_operand_str = "#{op} #{operands[0].to_s}"
        rest_operands_str = ""
      else
        first_operand_str = "#{operands[0].to_s} #{op} "
        rest_operands_str = (operands.skip(1).map {|o| o.to_s}).join(" ")
      end
      return "(#{first_operand_str}#{rest_operands_str})"
    end

    def children
      return operands
    end

    def ast_children : Array(Node)
      operands.map &.as(Node)
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

    def to_s : String
      "(new #{name.name} (#{(args.map &.to_s).join(", ")}))"
    end

    def children
      return args
    end

    def ast_children : Array(Node)
      [name.as(Node), args.map &.as(Node)].flatten
    end
  end

  # `ExprFieldAccess` represents a instance field access.
  class ExprFieldAccess < Expr
    property obj : Expr
    property field : Literal

    def initialize(@obj : Expr, @field : Literal)
    end

    def to_s : String
      "#{obj.to_s}.#{field.to_s}"
    end

    def children
      return [obj]
    end

    def ast_children : Array(Node)
      [obj.as(Node), field.as(Node)]
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

    def to_s : String
      return "#{arr_expr.to_s}[#{index.to_s}]" if arr_expr?
      return "#{arr_name.name}[#{index.to_s}]"
    end

    def children
      if arr_expr?
        return [arr_expr, index]
      else
        return [index]
      end
    end

    def ast_children : Array(Node)
      [arr_expr?.as?(Node), arr_name?.as?(Node), index.as(Node)].compact
    end
  end

  # `ExprArrayCreation` represents an array creation.
  class ExprArrayCreation < Expr
    # FIXME: (joey) Specialize the node type used here. Maybe if we
    # create a Type interface that multiple AST nodes can implement,
    # such as Name (or Class/Interface) and PrimitiveTyp.
    property arr : Node
    property dim : Expr

    def initialize(@arr : Node, @dim : Expr)
    end

    def to_s : String
      "(new array (TYPE: TODO) [])"
    end

    def ast_children : Array(Node)
      return
    end

    def children
      return [arr, dim]
    end

    def ast_children : Array(Node)
      # FIXME: (joey) dim not included due to the type specificity problem.
      [arr]
    end
  end

  # `ExprThis` represents the `this` expression, which will return the
  # currently scoped `this` instance.
  class ExprThis < Expr
    def initialize
    end

    def to_s : String
      "this"
    end

    def children
      [] of Expr
    end

    def ast_children : Array(Node)
      [] of Node
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

    def to_s : String
      name.name
    end

    def children
      [] of Expr
    end

    def ast_children : Array(Node)
      [name.as(Node)]
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
    property name : String
    property args : Array(Expr)

    def initialize(@expr : Expr | Nil, @name : String, @args : Array(Expr))
    end

    def to_s : String
      "(MethodInvoc: #{expr? ? expr.to_s : ""}.#{name} (#{(args.map &.to_s).join(", ")}))"
    end

    def children
      if expr?
        [expr] of Expr + args
      else
        args
      end
    end

    def ast_children : Array(Node)
      [expr?.as?(Node), args.map &.as(Node)].flatten.compact
    end
  end

  # `Const` are expressions with a constant value.
  abstract class Const < Expr
    def children
      [] of Expr
    end

    def ast_children : Array(Node)
      [] of Node
    end
  end

  class ConstInteger < Const
    # FIXME(joey): Make this a proper int val.
    property val : String

    def initialize(@val : String)
    end

    def to_s : String
      val
    end
  end

  class ConstBool < Const
    # FIXME(joey): Make this a proper bool val.
    property val : String

    def initialize(@val : String)
    end

    def to_s : String
      val
    end
  end

  class ConstChar < Const
    # FIXME(joey): Make this a proper char val.
    property val : String

    def initialize(@val : String)
    end

    def to_s : String
      "'#{val}'"
    end
  end

  class ConstString < Const
    property val : String

    def initialize(@val : String)
    end

    def to_s : String
      "\"#{val}\""
    end
  end

  class ConstNull < Const
    def initialize
    end

    def to_s : String
      "null"
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

    def ast_children : Array(Node)
      ([init?.as?(Node)] of Node?).compact
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
    property typ : Typ
    property var : VariableDecl

    def initialize(@typ : Typ, @var : VariableDecl)
    end

    def children
      if var.init.nil?
        return [] of Stmt
      else
        return [var.init]
      end
    end

    def ast_children : Array(Node)
      [typ.as(Node), var.as(Node)]
    end
  end

  # `MethodDecl` is a method declaration. It includes `name`, `typ,`
  # `modifiers`, `params` for the method signature, and the `body`.
  class MethodDecl < MemberDecl
    include Modifiers

    property name : String
    property typ : Typ
    property params : Array(Param) = [] of Param
    property! body : Array(Stmt) | Nil

    def initialize(@name : String, @typ : Typ, modifiers : Array(Modifier), @params : Array(Param), @body : Array(Stmt))
      self.modifiers = modifiers
    end

    class MethodSignature
      getter name : String
      getter typ : String
      getter modifiers : Set(String)
      getter params : Array(String)

      def initialize(@name : String, @typ : String, @modifiers : Set(String), @params : Array(String))
      end

      # Similar checks if the method signature is similar, i.e. it has
      # the same name.
      def similar(other : MethodSignature)
        self.name == other.name
      end

      # Equiv checks if the function signature is equivilant, i.e. the
      # name and formal parameters are equal.
      def equiv(other : MethodSignature)
        similar(other) && params_equiv(other)
      end

      def params_equiv(other : MethodSignature)
        params.size == other.params.size && params.zip(other.params).all? {|a, b| a == b}
      end
    end

    def signature : MethodSignature
      # FIXME(joey): Parameters in the method signature use the string
      # in the source tree. Both of the arguments have the same type,
      # but their signature will not match. This is incorrect, and
      # depends on resolving names in Typ to fix:
      #
      # ```java
      # foo(a java.lang.Object);
      # foo(a Object)
      # ```
      return MethodSignature.new(self.name, self.typ, self.modifiers, self.params.map(&.typ).map(&.name_str))
    end

    def ast_children : Array(Node)
      [
        typ.as(Node),
        params.map &.as(Node),
        body?.try {|b| b.map &.as(Node)},
      ].flatten.compact
    end
  end


  # `ConstructorDecl` is a specia lmethod declaration. It includes
  # `name`, `modifiers`, `params` for the method signature, and the
  # `body`. FIXME(joey): This can probably be squashed into `MethodDecl`
  # with a flag denoting it's a constructor with no type.
  class ConstructorDecl < MemberDecl
    include Modifiers

    property name : SimpleName
    property params : Array(Param) = [] of Param
    property body : Array(Stmt) = [] of Stmt

    def initialize(@name : SimpleName, modifiers : Array(Modifier), @params : Array(Param), @body : Array(Stmt))
      self.modifiers = modifiers
    end

    def ast_children : Array(Node)
      [name.as(Node), params.map &.as(Node), body.map &.as(Node)].flatten
    end
  end

  class ReturnStmt < Stmt
    property! expr : Expr | Nil

    def initialize(@expr : Expr | Nil)
    end

    def children
      if expr.nil?
        return [] of Expr
      else
        return [expr]
      end
    end

    def ast_children : Array(Node)
      ([expr?.as?(Node)] of Node?).compact
    end
  end

  class CastExpr < Expr
    property rhs : Expr
    property! typ : PrimitiveTyp
    property is_arr : Bool
    property! expr : Expr
    property! name : Name

    def initialize(@rhs : Expr, @typ : PrimitiveTyp, @is_arr : Bool)
    end

    def initialize(@rhs : Expr, @expr : Expr)
      @is_arr = false
    end

    def initialize(@rhs : Expr, @name : Name)
      @is_arr = true
    end

    def to_s : String
      type_str = (
        if typ?
          typ.name_str
        elsif expr?
          expr.to_s
        else
          name.name
        end
      )
      return "(Cast: type={#{type_str}} value={#{@rhs.to_s}})"
    end

    def children
      if expr?
        [rhs, expr] of Expr
      else
        [rhs] of Expr
      end
    end

    def ast_children : Array(Node)
      [typ?.as?(Node), expr?.as?(Node), name?.as?(Node), rhs.as(Node)].compact
    end
  end

  class ParenExpr < Expr
    property expr : Expr

    def initialize(@expr : Expr)
    end

    def children
      return [expr]
    end

    def to_s : String
      "(#{expr.to_s})"
    end

    def ast_children : Array(Node)
      [expr.as(Node)]
    end
  end

  class Variable < Expr
    property! name : Name
    property! array_access : ExprArrayAccess
    property! field_access : ExprFieldAccess

    def initialize(@name : Name)
    end

    def initialize(@array_access : ExprArrayAccess)
    end

    def initialize(@field_access : ExprFieldAccess)
    end

    def to_s : String
      if name?
        return name.name
      elsif array_access?
        return array_access.to_s
      else
        return field_access.to_s
      end
    end

    def children
      if name?
        return [] of Expr
      elsif array_access?
        return [array_access] of Expr
      elsif field_access?
        return [field_access] of Expr
      else
        raise Exception.new("unhandled case")
      end
    end

    def ast_children : Array(Node)
      [name?.as?(Node), array_access?.as?(Node), field_access?.as?(Node)].compact
    end
  end

  # TODO(joey): some notes on clean up to be done here:
  # - Replace tokens.to_a[i] access for children.
  # - Clean up casting. This is done to consoldiate rules within a few
  #   functions.
  # - Change how conditional values are retrieved. e.g. "Modifiers" is a
  #   common conditional where we want to default an empty array.

  # Intermediate ASTs. These do not appear in the final result but are
  # used to pass values up while doing simplificaiton.

  # Intermediate AST.
  class TMPMethodDecl < Node
    property name : String
    property params : Array(Param) = [] of Param

    def initialize(@name : String, @params : Array(Param))
    end

    def ast_children : Array(Node)
      [] of Node
    end
  end
end
