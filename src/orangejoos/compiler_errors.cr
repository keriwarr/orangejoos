# A ParseStageError is an error encountered during the parse stage.
class ParseStageError < Exception
end

# A ScanningStageError is an error encountered during the scan stage.
class ScanningStageError < Exception
  def initialize(exp : Exception, lexemes : Array(Lexeme))
    super("lexemes=#{lexemes}. exception=#{exp.backtrace.join("\n")}")
  end
end
