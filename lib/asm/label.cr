class ASM::Label
  property val : String

  def initialize(@val : String)
  end

  def to_s : String
    return val
  end

  def self.from_method(path : String, class_name : String, method : String, types : Array(String)) : Label
    return Label.new("method$#{path}$#{class_name}$#{method}##{types.join("#")}")
  end

  def self.from_ctor(path : String, class_name : String, types : Array(String)) : Label
    return Label.new("method$#{path}$#{class_name}$#__CTOR##{types.join("#")}")
  end

  def self.from_field(path : String, class_name : String, field : String) : Label
    return Label.new("field$#{path}$#{class_name}$#{field}")
  end
end
