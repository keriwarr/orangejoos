# The AST is a simple and easy to manipulate representation of the
# source code.

# TODO(joey): A great way to represent names and their resolved types
# would be adding functionality to `Name` to have a settable referenced
# type. That way each `Name` gets evaluated and a reference is added in
# that AST node, without having to add extra machinery in the parent
# node.

require "./visitor"
require "./mutating_visitor"
require "./typing"

# Type checking constants.
# FIXME(joey): Change these to sets.
BOOLEAN_OPS    = ["==", "!=", "&", "|", "^", "&&", "||"]
BINARY_NUM_OPS = ["+", "-", "/", "*", "%"]
UNARY_NUM_OPS  = ["+", "-"]
NUM_CMP_OPS    = [">", "<", "<=", ">=", "!=", "=="]

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
  # FIXME(joey): Move this to a better place. This was done to simplify
  # the code that refers to the not built-in String types.
  def self.get_string_type(namespace)
    string_class = namespace.fetch(QualifiedName.new(["java", "lang", "String"]))
    if string_class.nil?
      raise Exception.new("could not find java.lang.String to resolve for String literal")
    end
    return Typing::Type.new(Typing::Types::INSTANCE, string_class.not_nil!)
  end

  class MethodSignature
    getter name : String
    getter params : Array(Typing::Type)

    def initialize(@name : String, @params : Array(Typing::Type))
    end

    def self.constructor(params : Array(Typing::Type)) : MethodSignature
      return MethodSignature.new("<CONSTRUCTOR>", params)
    end

    def initialize(method : MethodDecl)
      @name = method.name
      @params = method.params.map { |p| p.typ.to_type }
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
      params.size == other.params.size && params.zip(other.params).all? { |a, b| a.equiv(b) }
    end

    def to_s
      return "(MethodSignature {#{name}} params=[#{params.map &.to_s}])"
    end
  end

  module Modifiers
    getter modifiers : Set(String) = Set(String).new

    def modifiers=(mods : Array(Modifier))
      @modifiers = Set(String).new(mods.map(&.name))
    end

    def add(mod : String)
      @modifiers = @modifiers.add(mod)
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

    def accept(v : Visitor::MutatingVisitor) : Node
      v.descend
      result = v.visit(self)
      v.ascend
      return result
    end

    # Implementations of this method should return all properties of
    # this node which are themselves Nodes.
    abstract def ast_children : Array(Node)
  end

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
    include Typing::Typed

    def initialize
    end

    abstract def to_s : String
  end

  # Typ represents all types.
  abstract class Typ < Node
    # The _cardinality_ array of the type. If the _cardinality_ is `0`, the
    # type is not an array. For example, the following type has a
    # cardinality of 2:
    # ```java
    # int[][]
    # ```
    property cardinality : Int32 = 0

    abstract def to_type : Typing::Type

    abstract def to_s : String

    abstract def ==(other : Typ) : Bool
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
    getter name : String

    def initialize(@name : String)
      @cardinality = 0
    end

    def initialize(@name : String, @cardinality : Int32)
    end

    # The _name_ of the type represented by the AST node.
    def to_s
      arr_str = "[]" * cardinality
      return "#{@name}#{arr_str}"
    end

    def ast_children : Array(Node)
      [] of Node
    end

    def to_type : Typing::Type
      is_array = @cardinality > 0
      case @name
      when "byte"    then return Typing::Type.new(Typing::Types::BYTE, is_array)
      when "short"   then return Typing::Type.new(Typing::Types::SHORT, is_array)
      when "int"     then return Typing::Type.new(Typing::Types::INT, is_array)
      when "char"    then return Typing::Type.new(Typing::Types::CHAR, is_array)
      when "boolean" then return Typing::Type.new(Typing::Types::BOOLEAN, is_array)
      else                raise Exception.new("unexpected type: #{@name}")
      end
    end
  end

  # `ClassType` represents user-defined Class and Interface types,
  # including the cardinality.
  class ClassTyp < Typ
    property name : Name
    property cardinality : Int32

    def initialize(@name : Name)
      @cardinality = 0
    end

    def initialize(@name : Name, @cardinality : Int32)
    end

    def to_s
      arr_str = "[]" * cardinality
      return "class:#{@name.name}#{arr_str}"
    end

    def ast_children : Array(Node)
      [name.as(Node)]
    end

    def to_type : Typing::Type
      is_array = @cardinality > 0
      return Typing::Type.new(Typing::Types::INSTANCE, name.ref.as(AST::TypeDecl), is_array)
    end
  end

  # `Identifier` is for identifiers, such as class names, method names,
  # and argument names.
  class Identifier < Node
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
  # package com.java.util
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
  # import com.java.util.Vector
  # ```
  #
  # or, for importing all of the contents of a package:
  #
  # ```java
  # import com.java.util.*
  # ```
  class ImportDecl < Node
    # The _path_ the import declaration is importing.
    property path : Name

    # _on_demand_ is whether the import is a wildcard import. An example
    # of that is:
    #
    # ```java
    # import java.util.*
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
    # NOTE: Interfaces are implicitly abstract, and are explicitly given the abstract modifier
    # during simplification
    include Modifiers

    property! name : String
    property! qualified_name : String

    # objectMethodDecls is used in InterfaceDecl
    abstract def all_methods(objectMethodDecls : Array(MethodDecl) = [] of MethodDecl) : Array(MethodDecl)
    abstract def methods(objectMethodDecls : Array(MethodDecl) = [] of MethodDecl) : Array(MethodDecl)
    abstract def super_methods(objectMethodDecls : Array(MethodDecl) = [] of MethodDecl) : Array(MethodDecl)
    abstract def non_static_fields : Array(FieldDecl)
    abstract def static_fields : Array(FieldDecl)
    abstract def all_non_static_fields : Array(FieldDecl)
    abstract def all_static_fields : Array(FieldDecl)

    def method?(name : String, args : Array(Typing::Type)) : MethodDecl?
      signature = MethodSignature.new(name, args)
      result = all_methods.find { |m| MethodSignature.new(m).equiv(signature) }
      return result
    end

    def ==(other : TypeDecl) : Bool
      return self.qualified_name == other.qualified_name
    end
  end

  # `ClassDecl` is a top-level declaration for classes. Classes contain
  # a name, a super class, implemented interfaces, and a list of field
  # and method declarations.
  class ClassDecl < TypeDecl
    property! super_class : Name
    getter interfaces : Array(Name) = [] of Name
    getter body : Array(MemberDecl) = [] of MemberDecl

    property is_inherited : Bool = false

    def initialize(@name : String, modifiers : Array(Modifier), @super_class : Name?, @interfaces : Array(Name), @body : Array(MemberDecl))
      self.modifiers = modifiers
    end

    def all_fields : Array(FieldDecl)
      # FIXME(joey): Modifier rules, for name resolution.
      visible_fields = body.map(&.as?(FieldDecl)).compact
      # TODO(joey): Filter out fields that will be shadowed. Currently,
      # there will be duplicates. The order of fields matter so that
      # shadowing fields will be near the front.
      visible_fields += super_class.ref.as(ClassDecl).all_fields if super_class?
      return visible_fields
    end

    def fields : Array(FieldDecl)
      body.map(&.as?(FieldDecl)).compact
    end

    def non_static_fields : Array(FieldDecl)
      fields.reject &.has_mod?("static")
    end

    def static_fields : Array(FieldDecl)
      fields.select &.has_mod?("static")
    end

    def all_non_static_fields : Array(FieldDecl)
      all_fields.reject &.has_mod?("static")
    end

    def all_static_fields : Array(FieldDecl)
      all_fields.select &.has_mod?("static")
    end

    def super_methods(objectMethodDecls : Array(MethodDecl) = [] of MethodDecl) : Array(MethodDecl)
      # TODO(joey): Filter out fields that will be shadowed. Currently,
      # there will be duplicates. The order of fields matter so that
      # shadowing fields will be near the front.
      visible_methods = [] of MethodDecl
      visible_methods += super_class.ref.as(ClassDecl).all_methods(objectMethodDecls) if super_class?
      interfaces.each do |i|
        interface = i.ref.as(InterfaceDecl)
        visible_methods += interface.all_methods(objectMethodDecls)
      end
      return visible_methods
    end

    def all_methods(objectMethodDecls : Array(MethodDecl) = [] of MethodDecl) : Array(MethodDecl)
      # FIXME(joey): Modifier rules, for name resolution.
      visible_methods = methods(objectMethodDecls)
      visible_methods += super_methods(objectMethodDecls)
      return visible_methods
    end

    def methods(objectMethodDecls : Array(MethodDecl) = [] of MethodDecl) : Array(MethodDecl)
      body.map(&.as?(MethodDecl)).compact
    end

    def constructors : Array(ConstructorDecl)
      body.map(&.as?(ConstructorDecl)).compact
    end

    def constructor?(args : Array(Typing::Type)) : ConstructorDecl?
      searching_sig = MethodSignature.constructor(args)
      result = constructors.find { |c| c.signature.equiv(searching_sig) }
      return result
    end

    def extends?(node : ClassDecl) : Bool
      return true if super_class? && super_class.ref.as(ClassDecl).qualified_name == node.qualified_name
      # TODO(joey): This is terribly inefficient lookup which could be
      # cached or precomputed in name resolution.
      return true if super_class? && super_class.ref.as(ClassDecl).extends?(node)
      return false
    end

    def implements?(node : InterfaceDecl) : Bool
      # TODO(joey): This function is terribly inefficient lookup which could be
      # cached or precomputed in name resolution.
      interfaces.each do |i|
        interface = i.ref.as(InterfaceDecl)
        return true if interface.qualified_name == node.qualified_name
        return true if interface.extends?(node)
      end
      return true if super_class? && super_class.ref.as(ClassDecl).implements?(node)
      return false
    end

    # Get the full package name of the class.
    def package
      qualified_name.split(".")[0...-1].join(".")
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

    # objectMethodDecls is a list of all the methods declared on the Object Class
    # JLS 9.2 has special rules about the usage of these methods when resolving
    # names in Interfaces
    # Passing in objectMethodDecls will attempt to add those methods to the returned methods
    def super_methods(objectMethodDecls : Array(MethodDecl) = [] of MethodDecl) : Array(MethodDecl)
      # TODO(joey): Filter out fields that will be shadowed. Currently,
      # there will be duplicates. The order of fields matter so that
      # shadowing fields will be near the front.
      visible_methods = [] of MethodDecl
      extensions.each do |i|
        interface = i.ref.as(InterfaceDecl)
        visible_methods += interface.all_methods(objectMethodDecls)
      end
      return visible_methods
    end

    # objectMethodDecls is a list of all the methods declared on the Object Class
    # JLS 9.2 has special rules about the usage of these methods when resolving
    # names in Interfaces
    # Passing in objectMethodDecls will attempt to add those methods to the returned methods
    def all_methods(objectMethodDecls : Array(MethodDecl) = [] of MethodDecl) : Array(MethodDecl)
      # FIXME(joey): Modifier rules, for name resolution.
      visible_methods = (
        if extensions.size > 0
          methods
        else
          methods(objectMethodDecls)
        end
      )
      visible_methods += super_methods(objectMethodDecls)
      return visible_methods
    end

    # Passing in objectMethodDecls will attempt to add those methods to the returned methods
    def methods(objectMethodDecls : Array(MethodDecl) = [] of MethodDecl) : Array(MethodDecl)
      explicit_methods = body.map(&.as?(MethodDecl)).compact
      methods = explicit_methods
      # For each objectMethodDecl, unless a method with the same signature and
      # return type was already declared in this interface, add an 'implicit'
      # declaration of that method
      objectMethodDecls.each do |objMethod|
        explicitly_defined = false
        explicit_methods.each do |method|
          if method.equiv(objMethod)
            explicitly_defined = true
          end
        end
        if !explicitly_defined
          methods.push(objMethod)
        end
      end

      return methods
    end

    def extends?(node : InterfaceDecl) : Bool
      # TODO(joey): This function is terribly inefficient lookup which could be
      # cached or precomputed in name resolution.
      extensions.each do |i|
        interface = i.ref.as(InterfaceDecl)
        return true if interface.qualified_name == node.qualified_name
        return true if interface.extends?(node)
      end
      return false
    end

    def non_static_fields : Array(FieldDecl)
      [] of FieldDecl
    end

    def static_fields : Array(FieldDecl)
      [] of FieldDecl
    end

    def all_non_static_fields : Array(FieldDecl)
      [] of FieldDecl
    end

    def all_static_fields : Array(FieldDecl)
      [] of FieldDecl
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

    # Override the above ref function with a more verbose nil assertion.
    def ref : Node
      return @ref.not_nil! if ref?
      raise Exception.new("nil assertion of Name.ref field. name=#{name}")
    end

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

    property! parent : TypeDecl

    abstract def name : String

    def check_field_access(current_class : ClassDecl, source_class : ClassDecl)
      # If the field is not protected, no access problems.
      return if !self.has_mod?("protected")
      # If the field's class is in the same package as the current class, no access problems.
      return if source_class.package == current_class.package
      # If the class being accessed is a super-class.
      return if current_class.extends?(source_class)
      # If the class being accessed is a sub-class, but the field is from a super-class (or this class).
      decl_class = self.parent.as(ClassDecl)
      return if source_class.extends?(current_class) && (current_class.extends?(decl_class) || current_class == decl_class)

      # Otherwise access is not permitted for the protected field.
      raise TypeCheckStageError.new("attempting to access protected member #{source_class.qualified_name}.{#{self.name}} from class #{current_class.qualified_name}}")
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
    property var : VariableDecl

    def initialize(modifiers : Array(Modifier), @typ : Typ, @var : VariableDecl)
      self.modifiers = modifiers
    end

    def name : String
      var.name
    end

    def ast_children : Array(Node)
      [typ.as(Node), var.as(Node)]
    end
  end

  # `File` is the root AST node. It holds all of the files top-level
  # declarations such the package (`PackageDecl`), imports
  # (`ImportDecl`) and classes/interfaces (`MemberDecl`).
  class File < Node
    property! package : PackageDecl
    property imports : Array(ImportDecl) = [] of ImportDecl
    property decls : Array(TypeDecl) = [] of TypeDecl

    def initialize(@package : PackageDecl?, @imports : Array(ImportDecl), @decls : Array(TypeDecl))
    end

    def decl?(name)
      decls.map(&.name).select(&.==(name)).size > 0
    end

    def decl(name) : TypeDecl
      results = decls.select { |decl| decl.name == name }
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
  # TODO(joey): If the Param wraps a `VariableDecl` or we remove `Param`
  # outright, this will simplify variable resolution code.
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

    def initialize(@init : Stmt?, @expr : Expr?, @update : Stmt?, @body : Stmt)
    end

    def children
      ([init?, expr?.as?(Stmt), update?, body] of Stmt?).compact
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

    def initialize(@expr : Expr, @if_body : Stmt, @else_body : Stmt?)
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

  # `ExprInstanceOf` is the instanceof expression. The LHS is an
  #  expression and the RHS is a type.
  class ExprInstanceOf < Expr
    property lhs : Expr
    property typ : Typ

    def initialize(@lhs : Expr, @typ : Typ)
    end

    def children
      return [lhs] of Expr
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      lhs_type = lhs.get_type(namespace)
      unless lhs_type.is_object? || lhs_type.is_array || lhs_type.typ == Typing::Types::NULL
        raise TypeCheckStageError.new("instanceof LHS must be reference type, got: #{lhs_type.to_s}")
      end
      return Typing::Type.new(Typing::Types::BOOLEAN)
    end

    def ast_children : Array(Node)
      [lhs.as(Node), typ.as(Node)]
    end

    def ast_children : Array(Node)
      [lhs, typ]
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
        rest_operands_str = (operands.skip(1).map { |o| o.to_s }).join(" ")
      end
      return "(#{first_operand_str}#{rest_operands_str})"
    end

    def children
      return operands
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      operand_typs = operands.map { |o| o.get_type(namespace).as(Typing::Type) }

      if operand_typs.any? { |o| o.is_type?(Typing::Types::VOID) }
        raise TypeCheckStageError.new("cannot use void return value in expression")
      end

      if BOOLEAN_OPS.includes?(op) && operands.size == 2 && operand_typs.all? { |t| t.is_type?(Typing::Types::BOOLEAN) }
        return Typing::Type.new(Typing::Types::BOOLEAN)
      end

      # NOTE: During integer operations inputs are always widened to
      # ints, and the resuling value is an int.

      if BINARY_NUM_OPS.includes?(op) && operands.size == 2 && operand_typs.all? { |t| t.is_number? || t.is_type?(Typing::Types::CHAR) }
        return Typing::Type.new(Typing::Types::INT)
      end

      if UNARY_NUM_OPS.includes?(op) && operands.size == 1 && operand_typs.all? { |t| t.is_number? || t.is_type?(Typing::Types::CHAR) }
        return Typing::Type.new(Typing::Types::INT)
      end

      if NUM_CMP_OPS.includes?(op) && operands.size == 2 && operand_typs.all? { |t| t.is_number? || t.is_type?(Typing::Types::CHAR) }
        return Typing::Type.new(Typing::Types::BOOLEAN)
      end

      if op == "!" && operands.size == 1 && operand_typs.all? { |t| t.is_type?(Typing::Types::BOOLEAN) }
        return Typing::Type.new(Typing::Types::BOOLEAN)
      end

      if op == "=" && operands.size == 2
        lhs = operand_typs[0]
        rhs = operand_typs[1]
        if Typing.can_assign_type(rhs, lhs)
          return lhs
        else
          raise TypeCheckStageError.new("assignment failure between LHS=#{operand_typs[0].to_s} RHS=#{operand_typs[1].to_s}")
        end
      end

      if ["==", "!="].includes?(op) && operands.size == 2
        lhs = operand_typs[0]
        rhs = operand_typs[1]
        if Typing.can_cast_type(rhs, lhs)
          return Typing::Type.new(Typing::Types::BOOLEAN)
        else
          raise TypeCheckStageError.new("equality between two different types: LHS=#{operand_typs[0].to_s} RHS#{operand_typs[1].to_s}")
        end
      end

      # When either type is a string during concat (+), then the other
      # type is casted to a String using `toString()` or converting the
      # primitive type.
      if op == "+" && operands.size == 2 &&
         (operand_typs[0] == AST.get_string_type(namespace) || operand_typs[1] == AST.get_string_type(namespace))
        return AST.get_string_type(namespace)
      end

      # FIXME(joey): Add exhaustive operators.
      types = operand_typs.map &.to_s
      raise TypeCheckStageError.new("unhandled operation: op=\"#{op}\" types=#{types} #{self}")
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
    property typ : ClassTyp
    property args : Array(Expr) = [] of Expr

    def initialize(@typ : ClassTyp, @args : Array(Expr))
    end

    def to_s : String
      "(new #{typ.to_s} (#{(args.map &.to_s).join(", ")}))"
    end

    def children
      return args
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      class_decl = typ.name.ref.as(ClassDecl)
      raise TypeCheckStageError.new("cannot initialize the abstract class #{class_decl.qualified_name}") if class_decl.has_mod?("abstract")

      arg_types = args.map &.get_type(namespace).as(Typing::Type)
      constructor = class_decl.constructor?(arg_types)
      raise TypeCheckStageError.new("no constructor with args (#{arg_types.map &.to_s}) on #{class_decl.qualified_name}") if constructor.nil?
      constructor = constructor.not_nil!
      return Typing::Type.new(Typing::Types::INSTANCE, class_decl)
    end

    def ast_children : Array(Node)
      [typ.as(Node), args.map &.as(Node)].flatten
    end
  end

  # `ExprFieldAccess` represents a instance field access.
  class ExprFieldAccess < Expr
    property obj : Expr
    property field_name : String

    def initialize(@obj : Expr, @field_name : String)
    end

    def to_s : String
      "#{obj.to_s}.#{field_name.to_s}"
    end

    def children
      return [obj]
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      typ = obj.get_type(namespace)
      unless typ.is_object? && typ.ref.is_a?(ClassDecl) || typ.is_array || typ.is_static?
        raise TypeCheckStageError.new("cannot access field of non-class type or non-array type")
      end
      if typ.is_array
        if @field_name != "length"
          raise TypeCheckStageError.new("array is not a field, can only access 'length'")
        end
        return Typing::Type.new(Typing::Types::INT)
      elsif typ.is_static?
        class_node = typ.ref.as(ClassDecl)
        field = class_node.all_static_fields.find { |f| f.var.name == @field_name }
        if field.nil?
          raise TypeCheckStageError.new("class {#{class_node.qualified_name}} has no static field {#{@field_name}}")
        end
        field.check_field_access(namespace.current_class, class_node)
        return field.not_nil!.typ.to_type
      elsif typ.is_object?
        class_node = typ.ref.as(ClassDecl)
        field = class_node.all_non_static_fields.find { |f| f.var.name == @field_name }
        if field.nil?
          raise TypeCheckStageError.new("class #{class_node.name} has no non-static field #{@field_name}")
        end
        field.check_field_access(namespace.current_class, class_node)
        return field.not_nil!.typ.to_type
      else
        raise Exception.new("unhandled case: #{typ.to_s}")
      end
    end

    def ast_children : Array(Node)
      [obj.as(Node)]
    end
  end

  # `ExprArrayAccess` represents an array access.
  class ExprArrayAccess < Expr
    property expr : Expr
    property index : Expr

    def initialize(@expr : Expr, @index : Expr)
    end

    def to_s : String
      return "#{expr.to_s}[#{index.to_s}]"
    end

    def children : Array(Expr)
      [expr, index]
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      typ = index.resolve_type(namespace)
      unless typ.is_number? || typ.is_type?(Typing::Types::CHAR)
        raise TypeCheckStageError.new("array index expression is not a number: expr=#{index.to_s}")
      end

      expr.get_type(namespace).from_array_type
    end

    def ast_children : Array(Node)
      [expr.as(Node), index.as(Node)].compact
    end
  end

  # `ExprArrayInit` represents an array creation.
  class ExprArrayInit < Expr
    # FIXME: (joey) Specialize the node type used here. Maybe if we
    # create a Type interface that multiple AST nodes can implement,
    # such as Name (or Class/Interface) and PrimitiveTyp.
    property arr : Typ
    property dim : Expr

    def initialize(@arr : Typ, @dim : Expr)
    end

    def to_s : String
      "(new array #{arr.to_s} [])"
    end

    def ast_children : Array(Node)
      return
    end

    def children
      return [arr, dim]
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      typ = dim.resolve_type(namespace)
      unless typ.is_number? || typ.is_type?(Typing::Types::CHAR)
        raise TypeCheckStageError.new("array init dimension expression is not a number: expr=#{dim.to_s}")
      end

      # Crystal cannot modify the type from a method, `#arr`.
      node = arr
      case node
      when PrimitiveTyp
        typ = node.to_type
        return typ.to_array_type
      when ClassTyp
        typ = node.to_type
        return typ.to_array_type
      else raise Exception.new("unexpected type: #{arr.inspect}")
      end
    end

    def ast_children : Array(Node)
      [arr.as(Node), dim.as(Node)]
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

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      # FIXME(joey): If the namespace is a static namespace, this should
      # be different.
      return Typing::Type.new(Typing::Types::INSTANCE, namespace.current_class)
    end

    def ast_children : Array(Node)
      [] of Node
    end
  end

  # `ExprRef` represents referenced values, such as fields or classes.
  # For example, the `x` in `1 + x` is an ExprRef:
  # ```java
  # int x
  # 1 + x
  # ```
  #
  class ExprRef < Expr
    # The _name_ of an `ExprRef` may hold one of:
    # - VarDeclStmt
    # - FieldDecl
    # - Param
    # - TypeDecl (ClassDecl / InterfaceDecl)
    property name : Name

    def initialize(@name : Name)
    end

    def to_s : String
      name.name
    end

    def children
      [] of Expr
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      if name.ref?
        node = name.ref
        case node
        when AST::TypeDecl
          return Typing::Type.new(Typing::Types::STATIC, node)
        when AST::VarDeclStmt then return node.typ.to_type
        when AST::Param       then return node.typ.to_type
        when AST::FieldDecl   then return node.typ.to_type
        else                       raise Exception.new("unhandled case: #{node.inspect}")
        end
      else
        raise TypeCheckStageError.new("ExprRef was not resolved: #{self.inspect}")
      end
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
    property expr : Expr
    property name : String
    property args : Array(Expr)

    def initialize(@expr : Expr, @name : String, @args : Array(Expr))
    end

    def to_s : String
      "(MethodInvoc: (#{expr.to_s}).#{name} (#{(args.map &.to_s).join(", ")}))"
    end

    def children
      [expr] of Expr + args
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      instance_type = expr.get_type(namespace)
      arg_types = args.map &.get_type(namespace).as(Typing::Type)
      raise TypeCheckStageError.new("attempted method call #{name} on #{instance_type.to_s}") unless instance_type.is_object? || instance_type.is_static?

      typ = instance_type.ref.as(AST::TypeDecl)
      method = typ.method?(name, arg_types)

      raise TypeCheckStageError.new("no method {#{name}}(#{arg_types.map &.to_s}) on #{typ.qualified_name}") if method.nil?

      method = method.not_nil!

      if instance_type.is_static?
        raise TypeCheckStageError.new("non-static method call {#{method.name}} with class #{instance_type.to_s}") unless method.has_mod?("static")
      else
        raise TypeCheckStageError.new("static method call {#{method.name}} with instance of #{instance_type.to_s}") if method.has_mod?("static")
      end

      if method.typ?
        return method.typ.to_type
      else
        return Typing::Type.new(Typing::Types::VOID)
      end
    end

    def ast_children : Array(Node)
      [expr.as(Node), args.map &.as(Node)].flatten.compact
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

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      # FIXME(joey): We may require more specific number types, or only
      # as a result of computation. I think constants evaluated to the
      # smallest type they can.
      return Typing::Type.new(Typing::Types::INT)
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

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      # FIXME(joey): We may require more specific number types, or only
      # as a result of computation.
      # I think constants evaluated to the smallest type they can.
      return Typing::Type.new(Typing::Types::BOOLEAN)
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

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      # FIXME(joey): We may require more specific number types, or only
      # as a result of computation.
      # I think constants evaluated to the smallest type they can.
      return Typing::Type.new(Typing::Types::CHAR)
    end
  end

  class ConstString < Const
    property val : String

    def initialize(@val : String)
    end

    def to_s : String
      "\"#{val}\""
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      return AST.get_string_type(namespace)
    end
  end

  class ConstNull < Const
    def initialize
    end

    def to_s : String
      "null"
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      return Typing::Type.new(Typing::Types::NULL)
    end
  end

  # `VariableDecl` represents variable declarations, including `name`,
  # `cardinality` and the expression to initialize the value of the
  # variable to (`init`).
  class VariableDecl < Node
    property name : String
    property! init : Expr

    def initialize(@name : String, @init : Expr?)
    end

    def ast_children : Array(Node)
      ([init?.as?(Node)] of Node?).compact
    end
  end

  # `VarDeclStmt` is a variable declaration statement. It wraps
  # `VariableDecl` to also include information about the `Typ` of the
  # `VariableDecl`.
  #
  # TODO(joey): Squash `VariableDecl` into this node. This will need to
  # be squashed into both the `FieldDecl` and `VarDeclStmt`. The only
  # difference is `FieldDecl` includes modifiers.
  class VarDeclStmt < Stmt
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
    # `typ` is Nil if the method has a void return type.
    property! typ : Typ
    property params : Array(Param) = [] of Param
    # `body` can be assigned to `Nil`, so even though it is a property! the
    # type signature needs to include `Nil`.
    property! body : Array(Stmt)?

    def initialize(@name : String, @typ : Typ?, modifiers : Array(Modifier), @params : Array(Param), @body : Array(Stmt))
      self.modifiers = modifiers
    end

    def signature : MethodSignature
      # FIXME(joey): Parameters in the method signature use the string
      # in the source tree. Both of the arguments have the same type,
      # but their signature will not match. This is incorrect, and
      # depends on resolving names in Typ to fix:
      #
      # ```java
      # foo(a java.lang.Object)
      # foo(a Object)
      # ```
      return MethodSignature.new(self)
    end

    # This method implements equivalency in the sense of what's relevant for
    # determining whether two methods clash with eachother during name resolution
    # i.e. same signature and return type
    def equiv(other : MethodDecl) : Bool
      # They must have the same signature
      return false unless self.signature.equiv(other.signature)
      # If they also both don't return a value, they're equivalent
      return true if self.typ?.nil? && other.typ?.nil?
      # If only one doesn't return a value they're not equivalent
      return false if self.typ?.nil? || other.typ?.nil?
      # Otherwise, are the types they return equivalent?
      return self.typ.to_type.equiv(other.typ.to_type)
    end

    def ast_children : Array(Node)
      [
        typ?.as?(Node),
        params.map &.as(Node),
        body?.try { |b| b.map &.as(Node) },
      ].flatten.compact
    end
  end

  # `ConstructorDecl` is a special method declaration. It includes
  # `name`, `modifiers`, `params` for the method signature, and the
  # `body`. FIXME(joey): This can probably be squashed into `MethodDecl`
  # with a flag denoting it's a constructor with no type.
  class ConstructorDecl < MemberDecl
    include Modifiers

    property name : String
    property params : Array(Param)
    property body : Array(Stmt) = [] of Stmt

    def initialize(@name : String, modifiers : Array(Modifier), @params : Array(Param), @body : Array(Stmt))
      self.modifiers = modifiers
    end

    def signature : MethodSignature
      return MethodSignature.constructor(params.map(&.typ.to_type))
    end

    def ast_children : Array(Node)
      [params.map &.as(Node), body.map &.as(Node)].flatten
    end
  end

  class ReturnStmt < Stmt
    property! expr : Expr

    def initialize(@expr : Expr?)
    end

    def children
      [expr?].compact
    end

    def ast_children : Array(Node)
      ([expr?.as?(Node)] of Node?).compact
    end
  end

  class CastExpr < Expr
    property rhs : Expr
    property typ : Typ

    def initialize(@rhs : Expr, @typ : Typ)
    end

    def to_s : String
      return "(Cast: type={#{typ.to_s}} value={#{rhs.to_s}})"
    end

    def children
      [rhs] of Expr
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      expr_type = rhs.get_type(namespace)
      raise TypeCheckStageError.new("cannot cast from #{expr_type.to_s} to #{typ.to_type.to_s}") if !Typing.can_cast_type(expr_type, typ.to_type)
      return typ.to_type
    end

    def ast_children : Array(Node)
      [typ, rhs]
    end
  end

  class ParenExpr < Expr
    property expr : Expr

    def initialize(@expr : Expr)
    end

    def children
      return [expr]
    end

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      return expr.get_type(namespace)
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

    def resolve_type(namespace : ImportNamespace) : Typing::Type
      if name?
        node = name.ref
        case node
        when VarDeclStmt then return node.typ.to_type
        when Param       then node.typ.to_type
        when FieldDecl   then node.typ.to_type
        else                  raise Exception.new("unhandled: #{node.inspect}")
        end
      elsif array_access?
        return array_access.get_type(namespace)
      elsif field_access?
        return field_access.get_type(namespace)
      else
        raise Exception.new("unhandled case")
      end
    end

    def ast_children : Array(Node)
      [name?.as?(Node), array_access?.as?(Node), field_access?.as?(Node)].compact
    end
  end
end
