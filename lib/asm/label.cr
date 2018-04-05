class ASM::Label

  MALLOC = Label.new("__malloc")

  property val : String

  def initialize(@val : String)
  end

  def to_s : String
    return val
  end

  def self.vtable(path : String, class_name : String) : Label
    return Label.new("VTABLE$#{path}$#{class_name}")
  end

  def self.from_interface(path : String, class_name : String, method : String, types : Array(String)) : Label
    return Label.new("IFACE$#{path}$#{class_name}$#{method}##{types.join("#")}")
  end

  def self.from_method(path : String, class_name : String, method : String, types : Array(String)) : Label
    return Label.new("METHOD$#{path}$#{class_name}$#{method}##{types.join("#")}")
  end

  def self.from_ctor(path : String, class_name : String, types : Array(String)) : Label
    return Label.new("CTOR$#{path}$#{class_name}##{types.join("#")}")
  end

  def self.from_class_for_init(path : String, class_name : String) : Label
    return Label.new("INTERNAL$#{path}$#{class_name}$#__INIT")
  end

  def self.from_static_field(path : String, class_name : String, field : String) : Label
    return Label.new("STATIC_FIELD$#{path}$#{class_name}$#{field}")
  end

  def self.from_static_init(path : String, class_name : String) : Label
    return Label.new("STATIC_INIT$#{path}$#{class_name}")
  end

  def self.from_string_literal(literal : String) : Label
    return Label.new("STRING_LITERAL$#{literal}")
  end

  def self.from_string_object_pointer(literal : String) : Label
    return Label.new("STRING_OBJECT_POINTER$#{literal}")
  end
end
