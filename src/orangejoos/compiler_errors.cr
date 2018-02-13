# A ScanningStageError is an error encountered during the scan stage.
class ScanningStageError < Exception
  def initialize(exp : String, lexemes : Array(Lexeme))
    super("lexemes=#{lexemes}. exception=#{exp}")
  end
end

# A ParseStageError is an error encountered during the parse stage.
class ParseStageError < Exception
end

# A SimplifyStageError is an error encountered during the simplify stage.
class SimplifyStageError < Exception
end

# A WeedingStageError is an error encountered during the weeding stage.
class WeedingStageError < Exception
end
