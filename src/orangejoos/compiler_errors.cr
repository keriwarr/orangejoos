# An ArgumentError is an error that occurs in the pipeline initialization stage,
# to signify that an argument is invalid
class ArgumentError < Exception
end

# Superclass tings
class CompilerError < Exception
  property! file : String

  @metadata : Array(Tuple(String, String)) = Array(Tuple(String, String)).new

  def register(key : String, val : String) : Nil
    @metadata.push(Tuple.new(key, val))
  end

  def metadata : String
    return @metadata.map { |k, v| "#{k}={#{v}}" }.join(" ")
  end
end

# A ScanningStageError is an error encountered during the scan stage.
class ScanningStageError < CompilerError
  def initialize(exp : String, lexemes : Array(Lexeme))
    super("lexemes=#{lexemes}. exception=#{exp}")
  end
end

# A ParseStageError is an error encountered during the parse stage.
class ParseStageError < CompilerError
end

# A SimplifyStageError is an error encountered during the simplify stage.
class SimplifyStageError < CompilerError
end

# A WeedingStageError is an error encountered during the weeding stage.
class WeedingStageError < CompilerError
end

# A NameResolutionStageError is an error encountered during the name
# resolution stage.
class NameResolutionStageError < CompilerError
end

# A TypeCheckStageError is an error encountered during the type check
# stage.
class TypeCheckStageError < CompilerError
end
