# Stage represents the stage of the compuler we wish to stop at.
enum Stage
  SCAN
  PARSE
  SIMPLIFY
  WEED
  NAME_RESOLUTION
  TYPE_CHECK
  ALL

  # takes a string and gets the corresponding enum token, or else raises an exception
  def self.get(stage : String) Stage
    case stage.downcase
    when "scan"     then return Stage::SCAN
    when "parse"    then return Stage::PARSE
    when "simplify" then return Stage::SIMPLIFY
    when "weed"     then return Stage::WEED
    when "nameresolution"     then return Stage::NAME_RESOLUTION
    when "typecheck"     then return Stage::TYPE_CHECK
    when "all"      then return Stage::ALL
    else raise Exception.new("got unexpected stage: \"#{stage}\"")
    end
  end
end
