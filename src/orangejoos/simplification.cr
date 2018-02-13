require "./compiler_errors.cr"
require "./parse_tree.cr"
require "./ast.cr"

struct Simplify::Rule
  def inititalize
  end
end

struct Simplify::Builder
  # Creates a new Simplify::Builder, yields with with `with ... yield`
  # and then returns the resulting string.
  def self.build
    new.build do |builder|
      with builder yield builder
    end
  end

  def initialize
    @rules = [] of Simplify::Rule
  end

  def build
    with self yield self
    @rules
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
    when "Interfaces"
      type_list = tree.tokens.get_tree!("InterfaceTypeList")
      return simplify_tree(type_list)
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

      # TODO(joey): ClassBody

      class_descl = AST::ClassDecl.new(name.val, modifiers, super_class, interfaces)
      return class_descl.as(AST::ClassDecl)
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

      # TODO(joey): InterfaceBody
      interface_body = [] of AST::Node

      class_descl = AST::InterfaceDecl.new(name.val, modifiers, extensions, interface_body)
      return class_descl.as(AST::InterfaceDecl)
    else
      raise Exception.new("unexepected tree name=#{tree.name}")
    end
  end
end
