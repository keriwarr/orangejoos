require "../visitor"
require "../ast"
require "asm/label"
require "ordered_hash"

# VTable represents the virtual table for a specific AST::ClassDecl.
# In general the format is as follows:
#
#   VTABLE$ClassName
#     ; [ INTERFACE METHODS ]
#     ...
#     ; [ METHODS ]
#     < superclass methods, starting with the "base" class (the one that extends nothing) >
#     < class methods that don't implement interfaces or override superclass methods >
#
class VTable
  include ASM::FileDSL

  # Interface => (Interface Method Declaration => Implementation by Class Method | Nil)
  alias Interfaces = OrderedHash(AST::InterfaceDecl, OrderedHash(AST::MethodDecl, AST::MethodDecl?))
  # Class => (Class Method => Override Method | Nil)
  alias Methods = OrderedHash(AST::ClassDecl, OrderedHash(AST::MethodDecl, AST::MethodDecl?))
  # Mehtod Signature => Offset in VTable
  alias Offsets = OrderedHash(AST::MethodSignature, Int32)

  property interfaces : Interfaces = Interfaces.new # interface method implementations
  property methods    : Methods = Methods.new       # class methods
  property offsets    : Offsets = Offsets.new       # offsets for all the things

  property exported_methods = Array(ASM::Label).new

  # Initialize creates the column and adds all the methods to it.
  # If the node has a super_class it will recurse up the extension tree and create
  # those columns first.
  def initialize(@vtables : VTableMap, @node : AST::ClassDecl)
    # If node has a super class we copy its methods, otherwise start from a base VTable with just interfaces.
    if @node.super_class? && !@node.super_class.ref.as(AST::ClassDecl).is_java_object?
      super_class = @node.super_class.ref.as(AST::ClassDecl)
      copy_methods(@vtables.new_vtable(super_class))
      @exported_methods += @vtables.exported_methods(super_class)
    else
      @vtables.interfaces.each do |i|
        @interfaces.push(i, OrderedHash(AST::MethodDecl, AST::MethodDecl?).new)
        i.body.each &.as?(AST::MethodDecl).try { |method| @interfaces[i].push(method, nil) }
      end
    end

    # Add own methods, implementing any interfaces and potentially overriding super methods.
    # Replaces superclass interface implementations if the method overrides.
    self_methods = OrderedHash(AST::MethodDecl, AST::MethodDecl?).new
    @node.methods.each do |method|
      @exported_methods.push(method.label) unless method.is_static? || method.is_protected? || @node.is_java_object?
      # we don't care about static methods since we know where those are at compile time
      next if method.is_static?
      # add interface implementations
      next if check_interface_impl!(method)
      # add superclass overrides
      next if check_super_override!(method)
      # else we add it to our own methods
      self_methods.push(method, nil)
    end
    @methods.push(@node, self_methods)

    generate_offsets
  end

  # generate_offsets creates the map of method signatures to VTable offset,
  # for use by the get_offset method
  def generate_offsets
    offset = 0
    @interfaces.each do |i, methods|
      methods.each do |method, impl|
        @offsets.push(impl.signature, offset) if !impl.nil?
        offset += 4
      end
    end

    @methods.each do |c, methods|
      methods.each do |method, override|
        @offsets.push(override.nil? ? method.signature : override.signature, offset)
        offset += 4
      end
    end
  end

  # get_offset returns the offset for the given method signature. We'll just let it explode
  # if it can't find the signature since that signals a programming error.
  def get_offset(method : AST::MethodSignature) : Int32
    return offsets[method]
  end

  # copies the other VTable's methods into self
  def copy_methods(other : VTable)
    @interfaces = other.interfaces.clone
    @methods = other.methods.clone
  end

  # check_interface_impl! checks to see if the passed method impements any interfaces, adding
  # the method as an implementation for any interface that @node implements.
  def check_interface_impl!(method : AST::MethodDecl) : Bool
    implemented? = false
    # Check for all interfaces that the method implements.
    @interfaces.each do |interface, methods|
      if @node.implements?(interface) && interface.method?(method)
        # Search for the method it implements and add implementation.
        # If a superclass implemented this already, override it.
        implemented? = true
        methods.each do |m, _|
          if method.equiv(m)
            @interfaces[interface][m] = method
            break
          end
        end
      end
    end
    implemented?
  end

  # check_super_override! checks if the given method overrides one of the node's superclass's methods,
  # and adds it as an override if it does.
  def check_super_override!(method : AST::MethodDecl) : Bool
    @methods.each do |clas, methods|
      methods.each do |clas_method, _|
        if (method.equiv(clas_method))
          @methods[clas][clas_method] = method
          return true
        end
      end
    end
    false
  end

  def label : ASM::Label
    return ASM::Label.vtable(@node.package, @node.name)
  end

  # asm outputs the vtable to the given FileDSL
  def asm(dsl : ASM::FileDSL)
    @buf = dsl.buf
    @next_comment = dsl.next_comment
    @annotating = dsl.annotating
    @indentation = dsl.indentation

    # print VTable label
    global label
    label label

    indent {
      # Print VTable interface methods
      comment "      [ INTERFACES ]"
      if @interfaces.size > 0
        @interfaces.each do |iface, methods|
            methods.each do |method, impl|
              comment_next_line "#{method.label.to_s}"
              if !impl.nil?
                asm_dd impl.label
              else
                asm_dd 0
            end
          end
        end
      else
        comment "No interfaces."
      end

      # Print VTable methods
      comment "      [ METHODS ]"
        @methods.each do |clas, methods|
          if methods.size > 0
          methods.each do |method, override|
            if override.nil?
              asm_dd method.label
            else
              comment_next_line "overrides #{method.label.to_s}"
              asm_dd override.label
            end
          end
        else
          comment "No non-static, non-interface methods."
        end
      end
    }
  end

  def pprint
    STDERR.puts @node.name
    STDERR.puts "\t[ INTERFACE IMPLEMENTATIONS ]"
    @interfaces.each do |iface, methods|
      STDERR.puts "\t\t#{iface.name}"
      methods.each do |m, i|
        STDERR.puts "\t\t\t#{m.label.to_s} #{i.nil? ? "unimplemented" : "implemented by #{i.label.to_s}"}"
      end
    end

    STDERR.puts "\t[ METHODS ]"
    @methods.each do |clas, methods|
      STDERR.puts "\t\t#{clas.name}"
      methods.each do |m, o|
        STDERR.puts "\t\t\t#{m.label.to_s}#{o.nil? ? "" : " overridden by " + o.label.to_s}"
      end
    end
    STDERR.puts "\n"

    STDERR.puts "\t[ METHOD OFFSETS ]"
    @offsets.each do |method, offset|
      STDERR.puts "\t\t#{method.to_s} => #{offset}"
    end
  end
end

# VTableMap is a hash of class declarations to their corresponding VTables.
class VTableMap
  include Enumerable({AST::ClassDecl, VTable})

  @class_vtables = {} of AST::ClassDecl => VTable
  @interface_table = OrderedHash(Tuple(AST::InterfaceDecl, AST::MethodSignature), Int32).new
  getter interfaces = [] of AST::InterfaceDecl # a collection of all interfaces in all ASTs.

  # the entire VTable is set up upon creation
  def initialize(@sources : Array(SourceFile))
    # Populate all interfaces methods so we can easily pop them into vtable columns.
    @sources.each { |file| file.ast.accept(InterfaceCollector.new(self)) }
    # Create a neato table for just the interfaces.
    offset = -4
    @interfaces.each { |i| i.methods.each {|m| @interface_table.push({i,m.signature}, offset += 4) }}
    # Add VTable entries for each class in each file
    @sources.each { |file| file.ast.accept(VTableCreator.new(self)) }
  end

  # new_vtable creates a new vtable and adds it to the table hash if it doesn't already exist, and returns
  # the table.
  def new_vtable(node : AST::ClassDecl) : VTable
    return @class_vtables[node] if @class_vtables[node]?       # check if node already has a VTable (created by subclass)
    return @class_vtables[node] = VTable.new(self, node) # otherwise create a new table for the node
  end

  # get_offset returns the offset of the given method in the vtable for typ
  def get_offset(typ : AST::TypeDecl, method : AST::MethodSignature) : Int32
    return @class_vtables[typ].get_offset(method)
    return @interface_table[{ typ, method.signature }]
    # this should probably never happen
    raise "Failed to get offset for #{method.to_s}."
  end

  def exported_methods(node : AST::ClassDecl) : Array(ASM::Label)
    if node.super_class? && !node.super_class.ref.as(AST::ClassDecl).is_java_object?
      return @class_vtables[node.super_class.ref.as(AST::ClassDecl)].exported_methods
    end
    return Array(ASM::Label).new
  end

  def label(node : AST::ClassDecl) : ASM::Label
    @class_vtables[node].label
  end

  # asm outputs the VTable for node to the given FileDSL
  def asm(dsl : ASM::FileDSL, node : AST::ClassDecl)
    @class_vtables[node].asm(dsl)
  end

  # pprint prints each VTable in the map all pretty like.
  def pprint
    @class_vtables.each { |_, vtable| vtable.pprint }
  end

  def each
    @class_vtables.each { |k,v| yield k, v }
  end
end


# InterfaceCollector collects all interfaces in the AST.
class InterfaceCollector < Visitor::GenericVisitor
  def initialize(@vtables : VTableMap)
  end

  def visit(node : AST::InterfaceDecl) : Nil
    @vtables.interfaces.push(node)
  end
end

# Visits each class and adds a VTable entry for that classes methods
class VTableCreator < Visitor::GenericVisitor
  def initialize(@vtables : VTableMap)
  end

  def visit(node : AST::ClassDecl) : Nil
    @vtables.new_vtable(node)
  end
end
