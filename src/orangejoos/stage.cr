# Stage represents the stage of the compuler we wish to stop at.
enum Stage
  SCAN
  PARSE
  SIMPLIFY
  WEED
  ALL

  # takes a string and gets the corresponding enum token, or else raises an exception
  def self.get(stage : String) Stage
    case stage
    when "scan"     then return Stage::SCAN
    when "parse"    then return Stage::PARSE
    when "simplify" then return Stage::SIMPLIFY
    when "weed"     then return Stage::WEED
    when "all"      then return Stage::ALL
    else raise Exception.new("got unexpected stage: \"#{stage}\"")
    end
  end
end
