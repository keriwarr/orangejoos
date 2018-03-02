require "./spec_helper"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# This spec tests the compiler pipeline up through to AST creation, including #
# weeding.                                                                    #
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

TABLE_FILE = "grammar/joos1w.lr1"
END_STAGE = "weed"
VALID   = "test/programs/valid"
INVALID = "test/programs/invalid"
PUB = "pub"

# get_files returns all java files in the directory and all subdirectories.
def get_files(dir : String) : Array(String)
  Dir.glob("#{dir}/**/*.java")
end

def get_files(dir : String, pattern : Regex) : Array(String)
  get_files(dir).select! { |x| x =~ pattern }
end

def cmd(stage : String, file : String) : String
  "./joosc -s #{stage} #{file}\n"
end

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Tests                                                                       #
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
describe "AST creation" do

  context "for valid programs:\n" do
    get_files(VALID).each do |file|
      context cmd(END_STAGE, file) do
        it "should successfuly run the entire pipeline, creating a weeded AST" do
          Pipeline.new(TABLE_FILE, [ file ], END_STAGE, false).exec.should be_true
        rescue ex : Exception
          fail "Expected Pipeline to run successfully, but instead got an exception."
        end
      end
    end
  end

  context "for invalid programs:\n" do
    get_files(INVALID).each do |file|
      context cmd(END_STAGE, file) do
        it "should fail to complete the pipeline, raising an Exception" do
          begin
            Pipeline.new(TABLE_FILE, [ file ], END_STAGE, false).exec
          rescue ex : PipelineError
            # pass
          rescue ex : Exception
            fail "Expected PipelineError to be raised, but got #{typeof(ex)} instead"
          end
        end
      end
    end
  end

end
