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

# Simplification is a stage that simplifies the initial parse tree.
# It transforms the parse tree into a proper AST that for use in later
# compiler stages.
class Simplification
  def initialize
  end

  def simplify(root : ParseTree) : AST::Node
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

  def simplify_tree(tree : ParseTree) # : Array(AST::Node) | Nil, but you cannot use that typedecl. It is inferred correctly.
    case tree.name
    when "ImportDeclarations"
      imports = tree.tokens.get_tree("ImportDeclarations")
      import_decls = [] of AST::ImportDecl
      import_decls = simplify_tree(imports).as(Array(AST::ImportDecl)) unless imports.nil?

      import = simplify(tree.tokens.get_tree!("ImportDeclaration")).as(AST::ImportDecl)
      import_decls.push(import)

      return import_decls

    when "TypeDeclarations"
      types = tree.tokens.get_tree("TypeDeclarations")
      type_decls = [] of AST::TypeDecl
      type_decls = simplify_tree(types).as(Array(AST::TypeDecl)) unless types.nil?

      typ = simplify(tree.tokens.get_tree!("TypeDeclaration"))
      type_decls.push(typ.as(AST::TypeDecl)) unless typ.nil?

      return type_decls

    when "ExtendsInterfaces"
      types = tree.tokens.get_tree("ExtendsInterfaces")
      type_decls = [] of AST::Name
      type_decls = simplify_tree(types).as(Array(AST::Name)) unless types.nil?

      type_decls.push(simplify(tree.tokens.get_tree!("InterfaceType")).as(AST::Name))

      return type_decls

    when "Modifiers"
      modifiers = tree.tokens.get_tree("Modifiers")
      modifiers_decls = [] of AST::Modifier
      modifiers_decls = simplify_tree(modifiers).as(Array(AST::Modifier)) unless modifiers.nil?

      mod = simplify(tree.tokens.get_tree!("Modifier"))
      modifiers_decls.push(mod.as(AST::Modifier)) unless mod.nil?
      return modifiers_decls

    when "InterfaceMemberDeclarations"
      members = tree.tokens.get_tree("InterfaceMemberDeclarations")
      members_decls = [] of AST::MemberDecl
      members_decls = simplify_tree(members).as(Array(AST::MemberDecl)) unless members.nil?

      decl = simplify(tree.tokens.get_tree!("InterfaceMemberDeclaration"))
      members_decls.push(decl.as(AST::MemberDecl)) unless decl.nil?
      return members_decls

    when "ClassBodyDeclarations"
      members = tree.tokens.get_tree("ClassBodyDeclarations")
      members_decls = [] of AST::MemberDecl
      members_decls = simplify_tree(members).as(Array(AST::MemberDecl)) unless members.nil?

      decl = simplify(tree.tokens.get_tree!("ClassBodyDeclaration"))
      members_decls.push(decl.as(AST::MemberDecl)) unless decl.nil?
      return members_decls

    when "Interfaces"
      type_list = tree.tokens.get_tree!("InterfaceTypeList")
      return simplify_tree(type_list)

    when "InterfaceBody"
      members = tree.tokens.get_tree("InterfaceMemberDeclarations")
      members_decls = [] of AST::MemberDecl
      members_decls = simplify_tree(members).as(Array(AST::MemberDecl)) unless members.nil?
      return members_decls

    when "ClassBody"
      members = tree.tokens.get_tree("ClassBodyDeclarations")
      members_decls = [] of AST::MemberDecl
      members_decls = simplify_tree(members).as(Array(AST::MemberDecl)) unless members.nil?
      return members_decls

    when "InterfaceTypeList"
      interfaces = tree.tokens.get_tree("InterfaceTypeList")
      interfaces_decls = [] of AST::Name
      interfaces_decls = simplify_tree(interfaces).as(Array(AST::Name)) unless interfaces.nil?

      interface = simplify(tree.tokens.get_tree!("InterfaceType"))
      interfaces_decls.push(interface.as(AST::Name)) unless interface.nil?
      return interfaces_decls

    when "FormalParameterList"
      params_t = tree.tokens.get_tree("FormalParameterList")
      params = [] of AST::Param
      params = simplify_tree(params_t).as(Array(AST::Param)) unless params_t.nil?

      param = simplify(tree.tokens.get_tree!("FormalParameter"))
      params.push(param.as(AST::Param)) unless param.nil?
      return params

    when "ArgumentList"
      exprs_t = tree.tokens.get_tree("ArgumentList")
      exprs = [] of AST::Expr
      exprs = simplify_tree(exprs_t).as(Array(AST::Expr)) unless exprs_t.nil?

      expr = simplify(tree.tokens.get_tree!("Expression"))
      exprs.push(expr.as(AST::Expr)) unless expr.nil?
      return exprs

    when "ArrayInitializer"
      exprs = [] of AST::Expr
      if (expr_tree = tree.tokens.get_tree("VariableInitializers")); !expr_tree.nil?
        exprs = simplify_tree(expr_tree).as(Array(AST::Expr))
      end
      return exprs

    when "VariableInitializers"
      var_inits = [] of AST::Expr
      var_inits_t = tree.tokens.get_tree("VariableInitializers")
      var_inits = simplify_tree(var_inits_t).as(Array(AST::Expr)) unless var_inits_t.nil?

      var_init = simplify(tree.tokens.get_tree!("VariableInitializer"))
      var_inits.push(var_init.as(AST::Expr)) unless var_init.nil?
      return var_inits

    when "BlockStatements"
      blocks = [] of AST::Stmt
      # FIXME (Simon) changed block -> block_tree here, which I think is correct.
      if (block_tree = tree.tokens.get_tree("BlockStatements")); !block_tree.nil?
        blocks = simplify_tree(block_tree).as(Array(AST::Stmt))
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


  def simplify(tree : ParseTree) : AST::Node | Nil
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
        return AST::ClassTyp.new(class_name)
      else
        # ArrayType or array reference type.
        return simplify(tree.tokens.first.as(ParseTree))
      end

    when "ArrayType"
      t = tree.tokens.first.as(ParseTree)
      case t.name
      when "Name"
        name = simplify(t).as(AST::Name)
        return AST::ClassTyp.new(name, 1)
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
      token = tree.tokens.first
      case token
      when Lexeme then return AST::PrimitiveTyp.new(token.sem)
      else raise Exception.new("unexpected case")
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
      return simplify(tree.tokens.first.as(ParseTree))

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
      elsif tree.tokens.first.as(ParseTree).name == "EmptyStatement"
        # FIXME(joey): I believe this is the easiest or only way to
        # represent EmptyStatement. Is this easy for the later parts of
        # the pipeline?
        return AST::Block.new([] of AST::Stmt)
      end
      return simplify(tree.tokens.first.as(ParseTree))

    when "EmptyStatement"
      # As the exception says, this node should never be traversed as it
      # is not peered into in the above case block. If this is
      # encountered, it is a bug.
      raise Exception.new("unexpected ParseNode \"EmptyStatement\", it should not be processed")

    when "StatementNoShortIf"
      return simplify(tree.tokens.first.as(ParseTree))

    when "ReturnStatement"
      expr = nil
      if (expression = tree.tokens.get_tree("Expression")); !expression.nil?
        expr = simplify(expression).as(AST::Expr)
      end

      return AST::ReturnStmt.new(expr)

    when "IfThenStatement", "IfThenElseStatement", "IfThenElseStatementNoShortIf"
      expr = simplify(tree.tokens.get_tree!("Expression")).as(AST::Expr)

      if_block = simplify(tree.tokens.to_a[4].as(ParseTree)).as(AST::Stmt)

      else_block = nil
      # IfThenStatement only has 5 parse nodes, while IfThenElse[...]
      # has 7.
      if tree.tokens.size > 6
        else_block = simplify(tree.tokens.to_a[6].as(ParseTree)).as(AST::Stmt)
      end

      return AST::IfStmt.new(expr, if_block, else_block)
    when "WhileStatement", "WhileStatementNoShortIf"
      expr = simplify(tree.tokens.get_tree!("Expression")).as(AST::Expr)
      if (stmt_tree = tree.tokens.get_tree("Statement")); !stmt_tree.nil?
        stmt = simplify(stmt_tree).as(AST::Stmt)
      else
        stmt_tree = tree.tokens.get_tree!("StatementNoShortIf")
        stmt = simplify(stmt_tree).as(AST::Stmt)
      end

      return AST::WhileStmt.new(expr, stmt)

    when "ForStatement", "ForStatementNoShortIf"
      init = nil
      if (init_tree = tree.tokens.get_tree("ForInit")); !init_tree.nil?
        init = simplify(init_tree).as(AST::Stmt)
      end

      expr = nil
      if (expr_tree = tree.tokens.get_tree("ForExpr")); !expr_tree.nil?
        expr = simplify(expr_tree).as(AST::Expr)
      end

      update = nil
      if (update_tree = tree.tokens.get_tree("ForUpdate")); !update_tree.nil?
        update = simplify(update_tree).as(AST::Stmt)
      end

      if (stmt_tree = tree.tokens.get_tree("Statement")); !stmt_tree.nil?
        stmt = simplify(stmt_tree).as(AST::Stmt)
      else
        stmt_tree = tree.tokens.get_tree!("StatementNoShortIf")
        stmt = simplify(stmt_tree).as(AST::Stmt)
      end

      return AST::ForStmt.new(init, expr, update, stmt)

    when "ExpressionStatement"
      return simplify(tree.tokens.first.as(ParseTree))

    when "StatementExpression"
      # NOTE: lmao, this rule name is not a typo.
      return simplify(tree.tokens.first.as(ParseTree))


    when "ForInit"
      return simplify(tree.tokens.first.as(ParseTree))

    when "ForUpdate"
      return simplify(tree.tokens.first.as(ParseTree))

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                            STATEMENTS                                   #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when "Expression"
      return simplify(tree.tokens.first.as(ParseTree))

    when "DimExpr"
      return simplify(tree.tokens.to_a[1].as(ParseTree))

    when "ConstantExpression"
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

      return simplify(tree.tokens.first.as(ParseTree)) if tree.tokens.size == 1

      if tree.tokens.to_a[1].as(Lexeme).sem == "instanceof"
        lhs = simplify(tree.tokens.first.as(ParseTree)).as(AST::Expr)
        typ = simplify(tree.tokens.to_a[2].as(ParseTree)).as(AST::Typ)
        return AST::ExprInstanceOf.new(lhs, typ)
      end

      lhs = simplify(tree.tokens.first.as(ParseTree)).as(AST::Expr)
      rhs = simplify(tree.tokens.to_a[2].as(ParseTree)).as(AST::Expr)
      op = tree.tokens.to_a[1].as(Lexeme).sem
      return AST::ExprOp.new(op, lhs, rhs)

    when "Assignment"
      return simplify(tree.tokens.first.as(ParseTree)) if tree.tokens.size == 1
      # else ...
      lhs_a = simplify(tree.tokens.first.as(ParseTree))
      lhs = lhs_a.as(AST::Variable)
      rhs = simplify(tree.tokens.to_a[2].as(ParseTree)).as(AST::Expr)
      # Only different here from the above case is the operator is
      # wrapped inside another parse node.
      op = tree.tokens.to_a[1].as(ParseTree).tokens.first.as(Lexeme).sem
      return AST::ExprOp.new(op, lhs, rhs)

    when "AssignmentOperator"
      # As the exception says, this node should never be traversed as it
      # is not peered into in the above case block. If this is
      # encountered, it is a bug.
      raise Exception.new("unexpected ParseNode \"AssignmentOperator\", this node should not be traversed")

    when "Dims"
      # As the exception says, this node should never be traversed as it
      # is not peered into in the above case block. If this is
      # encountered, it is a bug.
      raise Exception.new("unexpected ParseNode \"Dims\", this node should not be traversed")

    when "UnaryExpression", "UnaryExpressionNotPlusMinus"
      if tree.tokens.size == 1
        return simplify(tree.tokens.first.as(ParseTree))
      end
      op = tree.tokens.to_a[0].as(Lexeme).sem
      lhs = simplify(tree.tokens.to_a[1].as(ParseTree)).as(AST::Expr)

      if op == "-" && lhs.is_a?(AST::ConstInteger)
        constInteger = lhs.as(AST::ConstInteger)
        if constInteger.val.starts_with?("-")
          constInteger.val = constInteger.val.strip("-")
        else
          constInteger.val = "-" + constInteger.val
        end
        return constInteger
      end
      return AST::ExprOp.new(op, lhs)

    when "PostfixExpression"
      result = simplify(tree.tokens.first.as(ParseTree))
      case result
      # TODO(joey): we may want to refactor this to not be a thing.
      # This is done to convert Name types to an Expr.
      when AST::Name then return AST::ExprRef.new(result)
      else return result
      end

    when "Primary"
      return simplify(tree.tokens.first.as(ParseTree))

    when "PrimaryNoNewArray"
      # The following return is for "( Expr )", the only rule with 3 tokens
      return AST::ParenExpr.new(simplify(tree.tokens.to_a[1].as(ParseTree)).as(AST::Expr)) if tree.tokens.size == 3
      # else
      case tree.tokens.first
      # FIXME(joey): Seems weird to special case this. We may also not need to support
      # this and can remove it in the grammar.
      when Lexeme then return AST::ExprThis.new
      else return simplify(tree.tokens.first.as(ParseTree))
      end

    when "ClassInstanceCreationExpression"
      class_name = simplify(tree.tokens.get_tree!("ClassType")).as(AST::Name)

      args = [] of AST::Expr
      if (t = tree.tokens.get_tree("ArgumentList")); !t.nil?
        args = simplify_tree(t).as(Array(AST::Expr))
      end
      return AST::ExprClassInit.new(class_name, args)

    when "FieldAccess"
      obj = simplify(tree.tokens.get_tree!("Primary")).as(AST::Expr)
      field = simplify(tree.tokens.get_tree!("Identifier")).as(AST::Literal)

      return AST::ExprFieldAccess.new(obj, field)

    when "MethodInvocation"
      args = [] of AST::Expr
      if (t = tree.tokens.get_tree("ArgumentList")); !t.nil?
        args = simplify_tree(t).as(Array(AST::Expr))
      end

      # Check if the method invocation is either a `Name()` or an
      # `Primary.SimpleName()`. In the latter, we expect the `Expr` to
      # return a class or interface type.
      if !tree.tokens.get_tree("Name").nil?
        name = simplify(tree.tokens.get_tree!("Name")).as(AST::Name)
        return AST::MethodInvoc.new(nil, name.name, args)
      else
        expr = simplify(tree.tokens.get_tree!("Primary")).as(AST::Expr)
        ident = simplify(tree.tokens.get_tree!("Identifier")).as(AST::Literal)
        return AST::MethodInvoc.new(expr, ident.val, args)
      end

    when "ArrayAccess"
      arr = simplify(tree.tokens.to_a[0].as(ParseTree)).as(AST::Expr | AST::Name)
      index_expr = simplify(tree.tokens.to_a[2].as(ParseTree)).as(AST::Expr)
      # FIXME(joey): This is done to handle hacky type specificness for
      # the different ways of accessing an array.
      if arr.is_a?(AST::Expr)
        return AST::ExprArrayAccess.new(arr, index_expr)
      elsif arr.is_a?(AST::Name)
        return AST::ExprArrayAccess.new(arr, index_expr)
      else
        raise Exception.new("unexpected case")
      end

    when "CastExpression"
      rhs = simplify(tree.tokens.to_a.last.as(ParseTree)).as(AST::Expr)

      if !tree.tokens.get_tree("PrimitiveType").nil?
        typ = simplify(tree.tokens.get_tree!("PrimitiveType")).as(AST::PrimitiveTyp)
        dims = !tree.tokens.get_tree("Dims").nil?
        if dims
          typ = AST::PrimitiveTyp.new(typ.name, 1)
        end
        return AST::CastExpr.new(rhs, typ)
      else
        typ_name = simplify(tree.tokens.to_a[1].as(ParseTree))
        dims = !tree.tokens.get_tree("Dims").nil?
        cardinality = dims ? 1 : 0
        # We have to handle both Name and ExprRef because:
        # - We get Name if Dims is also present, i.e. only when it is
        #   casting to an array.
        # - We get ExprRef if Dims is not present, i.e. casting to a
        #   plain type).
        if typ_name.is_a?(AST::Name)
          typ = AST::ClassTyp.new(typ_name, cardinality)
        elsif typ_name.is_a?(AST::ExprRef)
          typ = AST::ClassTyp.new(typ_name.name, cardinality)
        else
          raise WeedingStageError.new("CastExpr expected a Name or Primative type to cast to, but got: #{typ_name.inspect}")
        end
        return AST::CastExpr.new(rhs, typ)
      end

    when "ArrayCreationExpression"
      # FIXME(joey): Specialize the node type used here.
      typ = simplify(tree.tokens.to_a[1].as(ParseTree)).as(AST::Node)
      dim_expr = simplify(tree.tokens.to_a[2].as(ParseTree)).as(AST::Expr)
      return AST::ExprArrayCreation.new(typ, dim_expr)

    when "LeftHandSide"
      result = simplify(tree.tokens.first.as(ParseTree)).as(AST::Name | AST::ExprArrayAccess | AST::ExprFieldAccess)
      # A `case` is used to to dereference the specific types.
      case result
      when AST::Name then return AST::Variable.new(result)
      when AST::ExprArrayAccess then return AST::Variable.new(result)
      when AST::ExprFieldAccess then return AST::Variable.new(result)
      else raise Exception.new("unexpected node #{result}")
      end

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                              LITERALS                                   #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when "Literal"
      return simplify(tree.tokens.first.as(ParseTree))

    when "IntegerLiteral"   then return AST::ConstInteger.new(tree.tokens.first.as(Lexeme).sem)
    when "BooleanLiteral"   then return AST::ConstBool.new(tree.tokens.first.as(Lexeme).sem)
    when "CharacterLiteral" then return AST::ConstChar.new(tree.tokens.first.as(Lexeme).sem)
    when "StringLiteral"    then return AST::ConstString.new(tree.tokens.first.as(Lexeme).sem)
    when "NullLiteral"      then return AST::ConstNull.new

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    #                            UNCATEGORIZED                                #
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    when "Super"                      then return simplify(tree.tokens.to_a[1].as(ParseTree))

    when "ClassType"
      # FIXME(joey): A marker should be added to the Name node here to
      # signify that the Name must resolve to a Class type.
      return simplify(tree.tokens.first.as(ParseTree))

    when "InterfaceType"
      # FIXME(joey): A marker should be added to the Name node here to
      # signify that the Name must resolve to an Interface type.
      return simplify(tree.tokens.first.as(ParseTree))

    when "ClassOrInterfaceType", "InterfaceMemberDeclaration",
         "ConstantDeclaration", "AbstractMethodDeclaration",
         "ClassBodyDeclaration", "ClassMemberDeclaration",
         "BlockStatement"
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

      # Note: We peer into the ConstructorDeclarator here, so we should
      # never call `simplify_tree` on a ConstructorDeclarator parse
      # node, hence the empty implementation below.
      if (params_t = tree.tokens.to_a[1].as(ParseTree).tokens.get_tree("FormatParameterList")); !params_t.nil?
        params = simplify_tree(params_t).as(Array(AST::Param))
      end
      body = simplify_tree(tree.tokens.to_a[2].as(ParseTree)).as(Array(AST::Stmt))
      return AST::ConstructorDecl.new(name, mods, params, body)

    when "ConstructorDeclarator"
      # This `ParseTree` should not be processed, because we never call
      # `simplify_tree` on it. Instead, the parent `ParseTree` peers
      # into the contents of this `ParseTree`, which is commented
      # immediately above.
      #
      # This implementation is meant to fulfill the simplification_spec
      # test, which checks for exhaustive rule implementations.
      raise Exception.new("unexpected ParseNode \"ConstructorImplementation\". See the comment in the code for why.")

    when "MethodDeclarator"
      if (decl = tree.tokens.get_tree("MethodDeclarator")); !decl.nil?
        return simplify(decl.as(ParseTree))
      end
      ident = simplify(tree.tokens.first.as(ParseTree)).as(AST::Literal)

      params = [] of AST::Param
      if (t = tree.tokens.get_tree("FormalParameterList")); !t.nil?
        params = simplify_tree(t.as(ParseTree)).as(Array(AST::Param))
      end

      return AST::TMPMethodDecl.new(ident.val, params)

    when "MethodHeader"
      t = tree.tokens.get_tree("Modifiers")
      mods = [] of AST::Modifier
      mods = simplify_tree(t).as(Array(AST::Modifier)) unless t.nil?

      typ_tree = tree.tokens.get_tree("Type")
      if typ_tree.nil?
        typ = AST::PrimitiveTyp.new("void")
      else
        typ = simplify(typ_tree.as(ParseTree)).as(AST::Typ)
      end

      decl = simplify(tree.tokens.get_tree("MethodDeclarator").as(ParseTree)).as(AST::TMPMethodDecl)

      return AST::MethodDecl.new(decl.name, typ, mods, decl.params, [] of AST::Stmt)

    when "VariableDeclaratorId"
      return simplify(tree.tokens.first.as(ParseTree))

    when "VariableDeclarator", "InitializedVariableDeclarator"
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
