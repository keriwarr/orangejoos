# The size of the base class, prior to the fields in the layout.
# TODO: (joey) As we currently do not have the vptr or type in the
# layout, this is 0.
BASE_SIZE = 4
VPTR_OFFSET = -4
TYP_OFFSET = 0


# `ClassInstance` is used for generating code involving a class
# instances, including field addressing and method invocation.
class ClassInstance
  property size : Int32 = 0

  # field name => (offset, decl)
  property fields = OrderedHash(String, Tuple(Int32, AST::FieldDecl)).new

  getter init_label : ASM::Label

  def initialize(cls : AST::ClassDecl)
    @init_label = ASM::Label.from_class_for_init(cls.package, cls.name)

    current_offset = 0
    # TODO: (joey) the offsets should account for super fields.
    cls.fields.each do |field|
      self.fields.push(field.name, Tuple.new(current_offset, field))
      # NOTE: currently, every data-type is only a double-word.
      current_offset += 4
    end

    self.size = BASE_SIZE + current_offset
  end

  def field_as_address(field : AST::FieldDecl)
    return Register::ESI.as_address_offset(BASE_SIZE + field_offset(field))
  end

  def field_offset(field : AST::FieldDecl)
    return fields[field.name][0]
  end
end
