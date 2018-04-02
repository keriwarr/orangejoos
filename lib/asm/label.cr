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

  def self.from_field(path : String, class_name : String, field : String) : Label
    return Label.new("FIELD$#{path}$#{class_name}$#{field}")
  end
end
