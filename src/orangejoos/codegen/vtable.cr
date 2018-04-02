require "../visitor"
require "../ast"
require "asm/label"
require "ordered_hash"

# A set of VTableColumns.
class VTable
  @table = {} of AST::ClassDecl => VTableColumn
  # a collection of all interfaces in all ASTs.
  property interfaces = [] of AST::InterfaceDecl

  # the entire VTable is set up upon creation
  def initialize(@sources : Array(SourceFile))
    # Populate all interfaces methods so we can easily pop them into vtable columns.
    @sources.each { |file| file.ast.accept(InterfaceVisitor.new(self)) }
    # Add VTable entries for each class in each file
    @sources.each { |file| file.ast.accept(VTableVisitor.new(self)) }
  end

  # add_column creates a VTableColumn for the given ClassDecl if it doesn't exist, and returns it
  def add_column(node : AST::ClassDecl): VTableColumn
    return @table[node] if @table[node]?
    return @table[node] = VTableColumn.new(self, node)
  end

  # prints the table all pretty like
  def pprint
    @table.each { |_, column| column.pprint }
  end

  # TODO(slnt) add interface for getting correct vtable offsets
end

# VTableColumn represents a VTable column for a specific class. Offsets in the VTable are
# only relative to superclasses that may have the same methods... or something
class VTableColumn
  # Interface => (Interface Method => Class Implementation | Nil)
  alias Interfaces = OrderedHash(AST::InterfaceDecl, OrderedHash(AST::MethodDecl, AST::MethodDecl?))
  # Class => (Class Method => Override Method | Nil)
  alias Methods = OrderedHash(AST::ClassDecl, OrderedHash(AST::MethodDecl, AST::MethodDecl?))

  # Interface methods.
  getter interfaces : Interfaces = Interfaces.new
  # Class methods.
  getter methods : Methods = Methods.new

  # Initialize creates the column and adds all the methods to it.
  # If the node has a super_class it will recurse up the extension tree and create
  # those columns first.
  def initialize(@vtable : VTable, @node : AST::ClassDecl)
    if @node.super_class?
      # If the node has a superclass, create that VTableColumn first, and then copy it.
      self.clone(@vtable.add_column(node.super_class.ref.as(AST::ClassDecl)))
    else
      # Otherwise we'll create the VTableColumn from scratch, starting with adding interfaces
      @vtable.interfaces.each do |i|
        @interfaces.push(i, OrderedHash(AST::MethodDecl, AST::MethodDecl?).new)
        i.body.each &.as?(AST::MethodDecl).try { |method| @interfaces[i].push(method, nil) }
      end
    end

    # Add own methods, implementing any interfaces and potentially overriding super methods.
    # Replaces superclass interface implementations if the method overrides.
    self_methods = OrderedHash(AST::MethodDecl, AST::MethodDecl?).new
    @node.methods.each do |method|
      # add interface implementations
      next if check_interface_impl!(method)
      # add superclass overrides
      next if check_super_override!(method)
      # else we add it to our own methods
      self_methods.push(method, nil)
    end
    @methods.push(@node, self_methods)

    # flatten (TODO) slnt: actually turn all this nice data we have into a real vtable, with offsets and stuff
    # so that its actually useful
  end

  # check_interface_impl! checks to see if the passed method impements any interfaces, adding
  # the method as an implementation for any interface that @node implements.
  def check_interface_impl!(method : AST::MethodDecl) : Bool
    implemented? = false
    # Check for all interfaces that the method implements.
    @interfaces.each do |interface, methods|
      if @node.implements?(interface) && interface.contains?(method)
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

  def clone(other : VTableColumn)
    # puts @node.name + " is cloning " + other.node.name
    # puts(other.interfaces)
    # put_interfaces(other.interfaces)
    @interfaces = other.interfaces.clone
    # puts(@interfaces)
    # put_interfaces(@interfaces)
    @methods = other.methods.clone
  end

  def label : ASM::Label
    return ASM::Label.vtable_column(@node.package, @node.name)
  end

  def pprint
    puts @node.name
    puts "\t[ INTERFACE IMPLEMENTATIONS ]"
    @interfaces.each do |iface, methods|
      puts "\t\t#{iface.name}"
      methods.each do |m, i|
        puts "\t\t\t#{m.label.to_s} => #{i.nil? ? "unimplemented" : i.label.to_s}"
      end
    end

    puts "\t[ METHODS ]"
    @methods.each do |clas, methods|
      puts "\t\t#{clas.name}"
      methods.each do |m, o|
        puts "\t\t\t#{m.label.to_s}#{o.nil? ? "" : " overridden by " + o.label.to_s}"
      end
    end
    puts "\n"
  end
end

# InterfaceVisitor finds all InterfaceDecls in then AST
class InterfaceVisitor < Visitor::GenericVisitor
  def initialize(@vtable : VTable)
  end

  def visit(node : AST::InterfaceDecl) : Nil
    @vtable.interfaces.push(node)
  end
end

# Visits each class and adds a VTable entry for that classes methods
class VTableVisitor < Visitor::GenericVisitor
  def initialize(@vtable : VTable)
  end

  def visit(node : AST::ClassDecl) : Nil
    @vtable.add_column(node)
  end
end
