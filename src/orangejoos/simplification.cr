require "./compiler_errors.cr"
require "./parse_tree.cr"
require "./ast.cr"

# I am sorry for this mess of hecticness :(
# TODO(joey): some notes on clean up to be done here:
# - Replace tokens.to_a[i] access for children.
# - Clean up casting. This is done to consoldiate rules within a few
#   functions.
# - Change how conditional values are retrieved. e.g. "Modifiers" is a
#   common conditional where we want to default an empty array.

# Intermediate ASTs. These do not appear in the final result but are
# used to pass values up while doing simplificaiton.
class TMPVarName < AST::Node
  property name : String
  property cardinality : Int32

  def initialize(@name : String, @cardinality : Int32)
  end

  def pprint(depth : Int32)
    raise Exception.new("unexpected call")
  end
end

# Intermediate AST.
class TMPMethodDecl < AST::Node
  property name : String
  property params : Array(AST::Param) = [] of AST::Param

  def initialize(@name : String, @params : Array(AST::Param))
  end

  def pprint(depth : Int32)
    raise Exception.new("unexpected call")
  end
end

# Simplification is a stage that simplifies the initial parse tree.
# It transforms the parse tree into a proper AST that for use in later
# compiler stages.
class Simplification
  def initialize(@root : ParseTree)
  end

  def simplify
    # We can safely assume the structure of the parse tree is correct
    # otherwise it would fail during the parse stage. During
    # simplification the only conditional are for optional tokens and
    # productions with multiple rules.

    # Call `simplify()` on the CompilationUnit tree.
    ret = simplify(@root)
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
    when "VariableDeclarators"
      vars = tree.tokens.get_tree("VariableDeclarators")
      vars_decls = [] of AST::VariableDecl
      if !vars.nil?
        vars_decls = simplify_tree(vars).as(Array(AST::VariableDecl))
      end

      decl = simplify(tree.tokens.get_tree!("VariableDeclarator"))
      if !decl.nil?
        vars_decls.push(decl.as(AST::VariableDecl))
      end
      return vars_decls
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
    else
      raise Exception.new("unexepected tree name=#{tree.name}")
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
        return AST::PrimativeTyp.new("boolean")
      else
        raise Exception.new("unexpected case")
      end
    when "NumericType"
      return simplify(tree.tokens.first.as(ParseTree))
    when "IntegralType"
      l = tree.tokens.first
      if l.is_a?(Lexeme)
        return AST::PrimativeTyp.new(l.sem)
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
    when "StaticInitializer"
      # TODO(joey)
    when "ConstructorDeclaration"
      # TODO(joey)
    when "MethodDeclaration"
      decl = simplify(tree.tokens.first.as(ParseTree)).as(AST::MethodDecl)

      # body = ...
      body = AST::Block.new

      decl.body = body
      return decl
    when "MethodDeclarator"
      decl = tree.tokens.get_tree("MethodDeclarator")
      if !decl.nil?
        # TODO(joey): There is an array suffix but I do not know what it
        # is for.
        return simplify(decl.as(ParseTree))
      end

      ident = simplify(tree.tokens.first.as(ParseTree)).as(AST::Literal)

      params = [] of AST::Param
      # TODO(joey): Parse parameters from FormalParameterList.

      return TMPMethodDecl.new(ident.val, params)
    when "MethodHeader"
      t = tree.tokens.get_tree("Modifiers")
      mods = [] of AST::Modifier
      if !t.nil?
        mods = simplify_tree(t).as(Array(AST::Modifier))
      end

      typ_tree = tree.tokens.get_tree("Type")
      if typ_tree.nil?
        typ = AST::PrimativeTyp.new("void")
      else
        typ = simplify(typ_tree.as(ParseTree)).as(AST::Typ)
      end

      decl = simplify(tree.tokens.get_tree("MethodDeclarator").as(ParseTree)).as(TMPMethodDecl)
      # TODO(joey): MethodDeclarator has an array suffix. I do not know
      # what it is for.

      return AST::MethodDecl.new(decl.name, typ, mods, decl.params, nil)
    when "VariableDeclaratorId"
      case tree.tokens.size
      when 1
          ident = simplify(tree.tokens.first.as(ParseTree)).as(AST::Literal)
          return TMPVarName.new(ident.val, 0)
      when 3
          var_name = simplify(tree.tokens.first.as(ParseTree)).as(TMPVarName)
          return TMPVarName.new(var_name.name, var_name.cardinality + 1)
      else
        raise Exception.new("unexpected token count: #{tree.tokens.size}")
      end
    when "VariableDeclarator"
      var_name = simplify(tree.tokens.first.as(ParseTree)).as(TMPVarName)
      name = var_name.name
      array_cardinality = var_name.cardinality
      # TODO(joey): Get the iniializer code.
      init = AST::VarInit.new
      return AST::VariableDecl.new(name, array_cardinality, init)
    when "FieldDeclaration"
      # FIXME(joey): This represents multiple fields. It should be
      # changed into an array, represented at the top-level.
      modifiers = [] of AST::Modifier
      if (modifiers_tree = tree.tokens.get_tree("Modifiers")); !modifiers_tree.nil?
        modifiers = simplify_tree(modifiers_tree).as(Array(AST::Modifier))
      end

      typ = simplify(tree.tokens.get_tree!("Type")).as(AST::Typ)

      decls = [] of AST::VariableDecl
      if (decls_tree = tree.tokens.get_tree("VariableDeclarators")); !decls_tree.nil?
        decls = simplify_tree(decls_tree).as(Array(AST::VariableDecl))
      end

      return AST::FieldDecl.new(modifiers, typ, decls)
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

      class_decl = AST::ClassDecl.new(name.val, modifiers, super_class, interfaces)
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
      raise Exception.new("unexepected node name=#{tree.name}")
    end
  end
end