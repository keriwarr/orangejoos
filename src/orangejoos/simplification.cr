require "./compiler_errors.cr"
require "./parse_tree.cr"
require "./ast.cr"
require "./lexeme.cr"

# UnexpectedNodeException helps us identify when a parse tree is
# rejected because it is not implemented yet.
class UnexpectedNodeException < Exception
end

# I am sorry for this mess :(
# In short, the simplify functions take parse rules and flattent them.
# Along the way, they generate AST nodes.
#
# `simplify_tree` returns arrays of AST nodes, `simplify` returns
# individual AST nodes.


# TODO(joey): some notes on clean up to be done here:
# - Replace tokens.to_a[i] access for children.
# - Clean up casting. This is done to consoldiate rules within a few
#   functions.
# - Change how conditional values are retrieved. e.g. "Modifiers" is a
#   common conditional where we want to default an empty array.

# Intermediate ASTs. These do not appear in the final result but are
# used to pass values up while doing simplificaiton.

# Intermediate AST.
class TMPMethodDecl < AST::Node
  property name : String
  property params : Array(AST::Param) = [] of AST::Param

  def initialize(@name : String, @params : Array(AST::Param))
  end

  def pprint(depth : Int32)
    raise Exception.new("unexpected call")
  end

  def accept(v : Visitor::Visitor) : Nil
    v.visit(self)
  end
end

# Simplification is a stage that simplifies the initial parse tree.
# It transforms the parse tree into a proper AST that for use in later
# compiler stages.
class Simplification
  def initialize
  end

  def simplify(root : ParseTree)
    # We can safely assume the structure of the parse tree is correct
    # otherwise it would fail during the parse stage. During
    # simplification the only conditional are for optional tokens and
    # productions with multiple rules.

    # Call `simplify()` on the CompilationUnit tree.
    ret = simplify(root)
    if ret.nil?
      raise Exception.new("expected non-nil simplified value")
    end
    return ret
  end

  def simplify_tree(tree : ParseTree)
    case tree.name
    when "ImportDeclarations"
      imports = tree.tokens.get_tree("ImportDeclarations")
      import_decls = [] of AST::ImportDecl
      if !imports.nil?
        import_decls = simplify_tree(imports).as(Array(AST::ImportDecl))
      end

      import = simplify(tree.tokens.get_tree!("ImportDeclaration")).as(AST::ImportDecl)
      import_decls.push(import)
      return import_decls

    when "TypeDeclarations"
      types = tree.tokens.get_tree("TypeDeclarations")
      type_decls = [] of AST::TypeDecl
      if !types.nil?
        type_decls = simplify_tree(types).as(Array(AST::TypeDecl))
      end

      typ = simplify(tree.tokens.get_tree!("TypeDeclaration"))
      if !typ.nil?
        type_decls.push(typ.as(AST::TypeDecl))
      end
      return type_decls

    when "Modifiers"
      modifiers = tree.tokens.get_tree("Modifiers")
      modifiers_decls = [] of AST::Modifier
      if !modifiers.nil?
        modifiers_decls = simplify_tree(modifiers).as(Array(AST::Modifier))
      end

      mod = simplify(tree.tokens.get_tree!("Modifier"))
      if !mod.nil?
        modifiers_decls.push(mod.as(AST::Modifier))
      end
      return modifiers_decls

    when "InterfaceMemberDeclarations"
      members = tree.tokens.get_tree("InterfaceMemberDeclarations")
      members_decls = [] of AST::MemberDecl
      if !members.nil?
        members_decls = simplify_tree(members).as(Array(AST::MemberDecl))
      end

      decl = simplify(tree.tokens.get_tree!("InterfaceMemberDeclaration"))
      if !decl.nil?
        members_decls.push(decl.as(AST::MemberDecl))
      end
      return members_decls

    when "ClassBodyDeclarations"
      members = tree.tokens.get_tree("ClassBodyDeclarations")
      members_decls = [] of AST::MemberDecl
      if !members.nil?
        members_decls = simplify_tree(members).as(Array(AST::MemberDecl))
      end

      decl = simplify(tree.tokens.get_tree!("ClassBodyDeclaration"))
      if !decl.nil?
        members_decls.push(decl.as(AST::MemberDecl))
      end
      return members_decls

    when "Interfaces"
      type_list = tree.tokens.get_tree!("InterfaceTypeList")
      return simplify_tree(type_list)

    when "InterfaceBody"
      members = tree.tokens.get_tree("InterfaceMemberDeclarations")
      members_decls = [] of AST::MemberDecl
      if !members.nil?
        members_decls = simplify_tree(members).as(Array(AST::MemberDecl))
      end
      return members_decls

    when "ClassBody"
      members = tree.tokens.get_tree("ClassBodyDeclarations")
      members_decls = [] of AST::MemberDecl
      if !members.nil?
        members_decls = simplify_tree(members).as(Array(AST::MemberDecl))
      end
      return members_decls

    when "InterfaceTypeList"
      interfaces = tree.tokens.get_tree("InterfaceTypeList")
      interfaces_decls = [] of AST::Name
      if !interfaces.nil?
        interfaces_decls = simplify_tree(interfaces).as(Array(AST::Name))
      end

      interface = simplify(tree.tokens.get_tree!("InterfaceType"))
      if !interface.nil?
        interfaces_decls.push(interface.as(AST::Name))
      end
      return interfaces_decls

    when "FormalParameterList"
      params_t = tree.tokens.get_tree("FormalParameterList")
      params = [] of AST::Param
      if !params_t.nil?
        params = simplify_tree(params_t).as(Array(AST::Param))
      end

      param = simplify(tree.tokens.get_tree!("FormalParameter"))
      if !param.nil?
        params.push(param.as(AST::Param))
      end
      return params

    when "ArgumentList"
      exprs_t = tree.tokens.get_tree("ArgumentList")
      exprs = [] of AST::Expr
      if !exprs_t.nil?
        exprs = simplify_tree(exprs_t).as(Array(AST::Expr))
      end

      expr = simplify(tree.tokens.get_tree!("Expression"))
      if !expr.nil?
        exprs.push(expr.as(AST::Expr))
      end
      return exprs

    when "BlockStatements"
      blocks = [] of AST::Stmt
      if (block_tree = tree.tokens.get_tree("BlockStatements")); !blocks.nil?
        blocks_decls = simplify_tree(block_tree).as(Array(AST::Stmt))
      end
      if (block = simplify(tree.tokens.get_tree!("BlockStatement"))); !block.nil?
        blocks.push(block.as(AST::Stmt))
      end
      return blocks

    when "Block"
      blocks = [] of AST::Stmt
      if (block_tree = tree.tokens.get_tree("BlockStatements")); !block_tree.nil?
        blocks = simplify_tree(block_tree).as(Array(AST::Stmt))
      end
      return blocks

    when "MethodBody"
      if (block_tree = tree.tokens.get_tree("Block")); !block_tree.nil?
        return simplify_tree(block_tree).as(Array(AST::Stmt))
      end
      # If there is no body, we return nil to denote no block for
      # abstract/not implemented methods
      return nil

    when "ConstructorBody"
      blocks = [] of AST::Stmt
      if (block_tree = tree.tokens.get_tree("BlockStatements")); !block_tree.nil?
        blocks = simplify_tree(block_tree).as(Array(AST::Stmt))
      end
      return blocks
    else
      raise UnexpectedNodeException.new("unexepected tree name=#{tree.name}")
    end
  end


  def simplify(tree : Lexeme)
    return nil
  end

  def simplify(tree : ParseTree)
    case tree.name
    when "Goal"
      return simplify(tree.tokens.first.as(ParseTree))

    when "CompilationUnit"
      package = nil
      if (package_tree = tree.tokens.get_tree("PackageDeclaration")); !package_tree.nil?
        package = simplify(package_tree).as(AST::PackageDecl)
      end

      imports = [] of AST::ImportDecl
      if (imports_tree = tree.tokens.get_tree("ImportDeclarations")); !imports_tree.nil?
        imports = simplify_tree(imports_tree).as(Array(AST::ImportDecl))
      end

      types = [] of AST::TypeDecl
      if (types_tree = tree.tokens.get_tree("TypeDeclarations")); !types_tree.nil?
        types = simplify_tree(types_tree).as(Array(AST::TypeDecl))
      end

      file = AST::File.new(package, imports, types)
      return file.as(AST::Node)

    when "PackageDeclaration"
      name = simplify(tree.tokens.get_tree!("Name")).as(AST::Name)
      return AST::PackageDecl.new(name)

    when "Name"
      if tree.tokens.size != 1
        raise Exception.new("unexpected token count: #{tree.tokens.size}")
      end
      return simplify(tree.tokens.first.as(ParseTree))

    when "SimpleName"
      if tree.tokens.size != 1
        raise Exception.new("unexpected token count: #{tree.tokens.size}")
      end
      literal = simplify(tree.tokens.first.as(ParseTree)).as(AST::Literal)
      return AST::SimpleName.new(literal.val)

    when "QualifiedName"
      if tree.tokens.size != 3
        raise Exception.new("unexpected token count: #{tree.tokens.size}")
      end

      start = simplify(tree.tokens.to_a.first.as(ParseTree))
      suffix = simplify(tree.tokens.to_a.last.as(ParseTree)).as(AST::Literal)

      case start
      when AST::SimpleName then return AST::QualifiedName.new([start.name, suffix.val])
      when AST::QualifiedName then return AST::QualifiedName.new(start.parts + [suffix.val])
      else
        raise Exception.new("unexpected first token: #{tree.tokens.first}")
      end

    when "Identifier"
      if tree.tokens.size != 1
        raise Exception.new("unexpected token count: #{tree.tokens.size}")
      end
      # FIXME(joey): This should not be a Literal but instead be an
      # Identifier maybe?
      return AST::Literal.new(tree.tokens.first.as(Lexeme).sem)

    when "Keyword"
      if tree.tokens.size != 1
        raise Exception.new("unexpected token count: #{tree.tokens.size}")
      end
      return AST::Keyword.new(tree.tokens.first.as(Lexeme).sem)

    when "Type"
      return simplify(tree.tokens.first.as(ParseTree))

    when "ReferenceType"
      class_tree = tree.tokens.get_tree("ClassOrInterfaceType")
      if !class_tree.nil?
        class_name = simplify(class_tree).as(AST::Name)
        return AST::ReferenceTyp.new(class_name)
      else
        # ArrayType or array reference type.
        return simplify(tree.tokens.first)
      end

    when "ArrayType"
      t = tree.tokens.first.as(ParseTree)
      case t.name
      when "Name"
        name = simplify(t).as(AST::Name)
        return AST::ReferenceTyp.new(name, 1)
      when "ArrayType", "PrimitiveType"
        typ = simplify(t).as(AST::Typ)
        typ.cardinality = typ.cardinality + 1
        return typ
      else
        raise Exception.new("unexpected case")
      end

    when "PrimitiveType"
       t = tree.tokens.first
      if t.is_a?(ParseTree)
        return simplify(t.as(ParseTree))
      elsif tree.tokens.first.is_a?(Lexeme)
        return AST::PrimitiveTyp.new("boolean")
      else
        raise Exception.new("unexpected case")
      end

    when "NumericType"
      return simplify(tree.tokens.first.as(ParseTree))

    when "IntegralType"
      l = tree.tokens.first
      if l.is_a?(Lexeme)
        return AST::PrimitiveTyp.new(l.sem)
      else
        raise Exception.new("unexpected case")
      end

    when "Modifier"
      if tree.tokens.size != 1
        raise Exception.new("unexpected token count: #{tree.tokens.size}")
      end
      return AST::Modifier.new(tree.tokens.first.as(Lexeme).sem)

    when "ImportDeclaration"
      if tree.tokens.size != 1
        raise Exception.new("unexpected token count: #{tree.tokens.size}")
      end
      return simplify(tree.tokens.first.as(ParseTree))

    when "TypeDeclaration"
      if tree.tokens.size != 1
        raise Exception.new("unexpected token count: #{tree.tokens.size}")
      end
      return simplify(tree.tokens.first)

    when "SingleTypeImportDeclaration"
      name = simplify(tree.tokens.to_a[1].as(ParseTree)).as(AST::Name)
      return AST::ImportDecl.new(name)

    when "TypeImportOnDemandDeclaration"
      name = simplify(tree.tokens.to_a[1].as(ParseTree)).as(AST::Name)
      return AST::ImportDecl.new(name, true)

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                            STATEMENTS                                   #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when "Statement"
      return simplify(tree.tokens.first.as(ParseTree))

    when "StatementWithoutTrailingSubstatement"
      if tree.tokens.first.as(ParseTree).name == "Block"
        stmts = simplify_tree(tree.tokens.first.as(ParseTree)).as(Array(AST::Stmt))
        return AST::Block.new(stmts)
      end
      return simplify(tree.tokens.first.as(ParseTree))

    when "StatementNoShortIf"
      return simplify(tree.tokens.first.as(ParseTree))

    when "ReturnStatement"
      # TODO(joey)

    when "IfThenStatement"
      # TODO(joey)

    when "IfThenElseStatement", "IfThenElseStatementNoShortif"
      # TODO(joey)

    when "WhileStatement", "WhileStatementNoShortif"
      # TODO(joey)

    when "ForStatement", "ForStatementNoShortif"
      # TODO(joey)

    when "ExpressionStatement"
      # TODO(joey)

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                            STATEMENTS                                   #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when "Expression"
      return simplify(tree.tokens.first.as(ParseTree))

    when "AssignmentExpression"
      return simplify(tree.tokens.first.as(ParseTree))

    # The following cases are similar parse tree structures, where the
    # middle token is the operator string we use anyways.
    when "ConditionalOrExpression",
         "ConditionalAndExpression",
         "InclusiveOrExpression",
         "AndExpression",
         "EqualityExpression",
         "RelationalExpression",
         "AdditiveExpression",
         "MultiplicativeExpression"
      if tree.tokens.size == 1
        return simplify(tree.tokens.first.as(ParseTree))
      end
      lhs_a = simplify(tree.tokens.first.as(ParseTree))
      lhs = lhs_a.as(AST::Expr)
      rhs = simplify(tree.tokens.to_a[2].as(ParseTree)).as(AST::Expr)
      op = tree.tokens.to_a[1].as(Lexeme).sem
      return AST::ExprOp.new(op, lhs, rhs)

    when "Assignment"
      if tree.tokens.size == 1
        return simplify(tree.tokens.first.as(ParseTree))
      end
      lhs_a = simplify(tree.tokens.first.as(ParseTree))
      lhs = lhs_a.as(AST::Expr)
      rhs = simplify(tree.tokens.to_a[2].as(ParseTree)).as(AST::Expr)
      # Only different here from the above case is the operator is
      # wrapped inside another parse node.
      op = tree.tokens.to_a[1].as(ParseTree).tokens.first.as(Lexeme).sem
      return AST::ExprOp.new(op, lhs, rhs)

    when "UnaryExpression", "UnaryExpressionNotPlusMinus"
      if tree.tokens.size == 1
        return simplify(tree.tokens.first.as(ParseTree))
      end
      op = tree.tokens.to_a[0].as(Lexeme).sem
      lhs = simplify(tree.tokens.to_a[1].as(ParseTree)).as(AST::Expr)
      return AST::ExprOp.new(op, lhs)

    when "PostfixExpression"
      result = simplify(tree.tokens.first.as(ParseTree))
      if result.is_a?(AST::Name)
        # TODO(joey): we may want to refactor this to not be a thing.
        # This is done to convert Name types to an Expr.
        return AST::ExprRef.new(result)
      end
      return result

    when "Primary"
      return simplify(tree.tokens.first.as(ParseTree))

    when "PrimaryNoNewArray"
      if tree.tokens.size == 3
        return simplify(tree.tokens.to_a[1].as(ParseTree))
      end
      if tree.tokens.first.is_a?(Lexeme)
        # FIXME(joey): Seems weird to special case this.
        # We also may not need to support this and can remove it in the
        # grammar.
        return AST::ExprThis.new
      end
      return simplify(tree.tokens.first.as(ParseTree))

    when "ClassInstanceCreationExpression"
      class_name = simplify(tree.tokens.get_tree!("ClassType")).as(AST::Name)

      args = [] of AST::Expr
      if (t = tree.tokens.get_tree("ArgumentList")); !t.nil?
        args = simplify_tree(t).as(Array(AST::Expr))
      end
      return AST::ExprClassInit.new(class_name, args)

    when "FieldAccess"
      # TODO(Joey)
      return AST::ExprThis.new

    when "MethodInvocation"
      # TODO(Joey)
      return AST::ExprThis.new

    when "ArrayAccess"
      # TODO(Joey)
      return AST::ExprThis.new

    when "CastExpression"
      # TODO(Joey)
      return AST::ExprThis.new

    when "ArrayCreationExpression"
      # TODO(Joey)
      return AST::ExprThis.new

    when "LeftHandSide"
      # FIXME(joey): Properly return an LValue type (name, field access, or array access).
      # result = simplify(tree.tokens.first.as(ParseTree)).as(AST::Name)
      # return AST::LValue.new()
      return AST::ExprThis.new

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                              LITERALS                                   #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when "Literal"
      return simplify(tree.tokens.first.as(ParseTree))

    when "IntegerLiteral"
      val = tree.tokens.first.as(Lexeme).sem
      return AST::ConstInteger.new(val)

    when "BooleanLiteral"
      val = tree.tokens.first.as(Lexeme).sem
      return AST::ConstBool.new(val)

    when "CharacterLiteral"
      val = tree.tokens.first.as(Lexeme).sem
      return AST::ConstChar.new(val)

    when "StringLiteral"
      val = tree.tokens.first.as(Lexeme).sem
      return AST::ConstString.new(val)

    when "NullLiteral"
      return AST::ConstNull.new

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                            UNCATEGORIZED                                #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when "Super"
      return simplify(tree.tokens.to_a[1].as(ParseTree))

    when "ClassType"
      return simplify(tree.tokens.first.as(ParseTree))

    when "InterfaceType"
      return simplify(tree.tokens.first.as(ParseTree))

    when "ClassOrInterfaceType"
      return simplify(tree.tokens.first.as(ParseTree))

    when "InterfaceMemberDeclaration"
      return simplify(tree.tokens.first.as(ParseTree))

    when "ConstantDeclaration"
      return simplify(tree.tokens.first.as(ParseTree))

    when "AbstractMethodDeclaration"
      return simplify(tree.tokens.first.as(ParseTree))

    when "ClassBodyDeclaration"
      return simplify(tree.tokens.first.as(ParseTree))

    when "ClassMemberDeclaration"
      return simplify(tree.tokens.first.as(ParseTree))

    when "BlockStatement"
      return simplify(tree.tokens.first.as(ParseTree))

    when "LocalVariableDeclarationStatement"
      return simplify(tree.tokens.first.as(ParseTree))

    when "LocalVariableDeclaration"
      typ = simplify(tree.tokens.first.as(ParseTree)).as(AST::Typ)
      var_decl = simplify(tree.tokens.to_a[1].as(ParseTree)).as(AST::VariableDecl)
      return AST::DeclStmt.new(typ, var_decl)

    when "FormalParameter"
      typ = simplify(tree.tokens.first.as(ParseTree)).as(AST::Typ)
      var_name = simplify(tree.tokens.to_a[1].as(ParseTree)).as(AST::Literal).val
      return AST::Param.new(var_name, typ)

    when "MethodDeclaration"
      decl = simplify(tree.tokens.first.as(ParseTree)).as(AST::MethodDecl)
      body = simplify_tree(tree.tokens.to_a[1].as(ParseTree)).as(Array(AST::Stmt) | Nil)
      decl.body = body
      return decl

    when "ConstructorDeclaration"
      mods = simplify_tree(tree.tokens.get_tree!("Modifiers")).as(Array(AST::Modifier))
      name = simplify(tree.tokens.to_a[1].as(ParseTree).tokens.to_a[0].as(ParseTree)).as(AST::SimpleName)
      params = [] of AST::Param

      if (params_t = tree.tokens.to_a[1].as(ParseTree).tokens.get_tree("FormatParameterList")); !params_t.nil?
        params = simplify_tree(params_t).as(Array(AST::Param))
      end
      body = simplify_tree(tree.tokens.to_a[2].as(ParseTree)).as(Array(AST::Stmt))
      return AST::ConstructorDecl.new(name, mods, params, body)

    when "MethodDeclarator"
      if (decl = tree.tokens.get_tree("MethodDeclarator")); !decl.nil?
        return simplify(decl.as(ParseTree))
      end
      ident = simplify(tree.tokens.first.as(ParseTree)).as(AST::Literal)

      params = [] of AST::Param
      if (t = tree.tokens.get_tree("FormalParameterList")); !t.nil?
        params = simplify_tree(t.as(ParseTree)).as(Array(AST::Param))
      end

      return TMPMethodDecl.new(ident.val, params)

    when "MethodHeader"
      t = tree.tokens.get_tree("Modifiers")
      mods = [] of AST::Modifier
      if !t.nil?
        mods = simplify_tree(t).as(Array(AST::Modifier))
      end

      typ_tree = tree.tokens.get_tree("Type")
      if typ_tree.nil?
        typ = AST::PrimitiveTyp.new("void")
      else
        typ = simplify(typ_tree.as(ParseTree)).as(AST::Typ)
      end

      decl = simplify(tree.tokens.get_tree("MethodDeclarator").as(ParseTree)).as(TMPMethodDecl)

      return AST::MethodDecl.new(decl.name, typ, mods, decl.params, [] of AST::Stmt)

    when "VariableDeclaratorId"
      return simplify(tree.tokens.first.as(ParseTree))

    when "VariableDeclarator"
      var_name = simplify(tree.tokens.first.as(ParseTree)).as(AST::Literal).val

      init = nil
      if (t = tree.tokens.get_tree("VariableInitializer")); !t.nil?
        init = simplify(t).as(AST::Expr)
      end

      return AST::VariableDecl.new(var_name, init)

    when "VariableInitializer"
      return simplify(tree.tokens.first.as(ParseTree))

    when "FieldDeclaration"
      modifiers = [] of AST::Modifier
      if (modifiers_tree = tree.tokens.get_tree("Modifiers")); !modifiers_tree.nil?
        modifiers = simplify_tree(modifiers_tree).as(Array(AST::Modifier))
      end

      typ = simplify(tree.tokens.get_tree!("Type")).as(AST::Typ)

      decl = simplify(tree.tokens.get_tree!("VariableDeclarator")).as(AST::VariableDecl)

      return AST::FieldDecl.new(modifiers, typ, decl)

    when "ClassDeclaration"
      name = simplify(tree.tokens.get_tree!("Identifier")).as(AST::Literal)

      modifiers = [] of AST::Modifier
      if (modifiers_tree = tree.tokens.get_tree("Modifiers")); !modifiers_tree.nil?
        modifiers = simplify_tree(modifiers_tree).as(Array(AST::Modifier))
      end

      super_class = nil
      if (super_tree = tree.tokens.get_tree("Super")); !super_tree.nil?
        super_class = simplify(super_tree).as(AST::Name)
      end

      interfaces = [] of AST::Name
      if (interfaces_tree = tree.tokens.get_tree("Interfaces")); !interfaces_tree.nil?
        interfaces = simplify_tree(interfaces_tree).as(Array(AST::Name))
      end

      member_decls = [] of AST::MemberDecl
      if (body_tree = tree.tokens.get_tree("ClassBody")); !body_tree.nil?
        member_decls = simplify_tree(body_tree).as(Array(AST::MemberDecl))
      end

      class_decl = AST::ClassDecl.new(name.val, modifiers, super_class, interfaces, member_decls)
      return class_decl

    when "InterfaceDeclaration"
      name = simplify(tree.tokens.get_tree!("Identifier")).as(AST::Literal)

      modifiers = [] of AST::Modifier
      if (modifiers_tree = tree.tokens.get_tree("Modifiers")); !modifiers_tree.nil?
        modifiers = simplify_tree(modifiers_tree).as(Array(AST::Modifier))
      end

      extensions = [] of AST::Name
      if (extensions_tree = tree.tokens.get_tree("ExtendsInterfaces")); !extensions_tree.nil?
        extensions = simplify_tree(extensions_tree).as(Array(AST::Name))
      end

      member_decls = [] of AST::MemberDecl
      if (body_tree = tree.tokens.get_tree("InterfaceBody")); !body_tree.nil?
        member_decls = simplify_tree(body_tree).as(Array(AST::MemberDecl))
      end

      iface_decl = AST::InterfaceDecl.new(name.val, modifiers, extensions, member_decls)
      return iface_decl
    else
      raise UnexpectedNodeException.new("unexepected node name=#{tree.name}")
    end
  end
end
