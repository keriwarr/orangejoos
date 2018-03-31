require "./spec_helper"
require "../src/orangejoos/stage"
require "../src/orangejoos/pipeline"

# Args for compilation.
TABLE_FILE = "grammar/joos1w.lr1"
END_STAGE = Stage::CODE_GEN
VERBOSE = false
USE_STDLIB = true
COMPILATION_OUTPUT_DIR = "output"

# Gets the codegen test cases to run. The a5 test cases are searched. An
# environment variable _TESTS_ can be provided, which is a comma
# delimitered case-insensitive list of names to match against.
def get_test_cases : Array(String)
  # Fetch all of the test cases.
  cases = Dir.glob("pub/assignment_testcases/a5/*")

  if ENV.has_key?("TESTS")
    accepting_cases = ENV["TESTS"].split(",")
    accepting_cases.map {|t| Regex.escape(t) }
    accepting_cases = accepting_cases.join(",")
    accepting_regex = Regex.new("(#{accepting_cases})[/\\.]", Regex::Options::IGNORE_CASE)

    cases = cases.select {|c| accepting_regex.match(c) }
  end

  return cases
end

# Fetch all of the stdlib files.
STDLIB_FILES = Dir.glob("pub/stdlib/5.0/**/*.java")


# Fetches all test files for a given test name, including the standard
# library files.
def get_test_files(test_case : String) : Array(String)
  if File.file?(test_case)
    test_files = [test_case]
  else
    test_files = Dir.glob("#{test_case}/**/*.java")
  end

  test_files += STDLIB_FILES
end

class NASMCompilationError < Exception
end

class LinkerError < Exception
end

class JavaCompilationError < Exception
end

def compile_asm(in_file : String)
  out_filename = File.basename(in_file, ".s") + ".o"
  out_file = File.join(COMPILATION_OUTPUT_DIR, out_filename)
  io = IO::Memory.new
  res = Process.run("nasm -O1 -f macho -F dwarf -g #{in_file} -o #{out_file}", shell: true, output: io)
  output = io.to_s
  if res.exit_code != 0 || output != ""
    raise NASMCompilationError.new("status=#{res.exit_code} output: #{output}")
  end
end

def link_object_files
  out_file = File.join(COMPILATION_OUTPUT_DIR, "main")
  in_files = File.join(COMPILATION_OUTPUT_DIR, "*.o")
  io = IO::Memory.new
  res = Process.run("ld -o #{out_file} #{in_files}", shell: true, output: io)
  output = io.to_s
  if res.exit_code != 0 || output != ""
    raise LinkerError.new("status=#{res.exit_code} output: #{output}")
  end
end

def run_compiled_binary : NamedTuple(code: Int32, output: String)
  file = File.join(COMPILATION_OUTPUT_DIR, "main")
  io = IO::Memory.new
  res = Process.run("./#{file}", shell: true, output: io)
  output = io.to_s
  return {code: res.exit_code, output: output}
end

def compile_java_test(test_files : Array(String))
  # Do not include Joos1W stdlib, as they are built into java.
  test_files = test_files.select { |f| !f.includes?("stdlib") }
  io = IO::Memory.new
  res = Process.run("javac -d #{COMPILATION_OUTPUT_DIR} spec/java_fixtures/Wrapper.java #{test_files.join(" ")}", shell: true, output: io, error: io)
  output = io.to_s
  if res.exit_code != 0 || output != ""
    raise JavaCompilationError.new("status=#{res.exit_code} output: #{output}")
  end
end

def run_java_binary(test_case_name : String, is_dir : Bool) : NamedTuple(code: Int32, output: String)
  if is_dir
    entry_class_name = "Main"
  else
    entry_class_name = test_case_name
  end
  io = IO::Memory.new
  error_io = IO::Memory.new
  res = Process.run("java -cp #{COMPILATION_OUTPUT_DIR} orangejoos.Wrapper #{entry_class_name}", shell: true, output: io, error: error_io)
  output = io.to_s
  err_output = error_io.to_s
  STDERR.puts err_output if err_output != ""
  return {code: res.exit_code, output: output}
end

describe "Codegen" do
  # 0. Fetch all of the test cases.
  cases = get_test_cases

  # go through each test case.
  cases.each do |test_case|
    test_files = get_test_files(test_case)
    test_case_name = File.basename(test_case, ".java")

    it "#{test_case_name} compiles" do
      # 1. compile the Joos1W program.
      # NOTE: this will clear the output directory on each pipeline run.
      # TODO: (joey) can we omit stdlib for tests that do not require
      # it. we would need to manually mark tests.
      # TODO: (joey) can we pre-compile the stdlib once for all tests.
      # unfortunately, that means the tests need to reach into the pipeline.
      Pipeline.new(TABLE_FILE, test_files, END_STAGE, VERBOSE, USE_STDLIB, COMPILATION_OUTPUT_DIR).exec

      # 1.b compile the asm to object files.
      asm_files = Dir.glob("#{COMPILATION_OUTPUT_DIR}/*.s")
      asm_files.each {|f| compile_asm(f) }
      # 1.c link the object files to a binary.
      link_object_files

      it "is executes" do
        # 2. execute the Joos1W program, recording:
        # - stdout
        # - status code
        # - any exception (how?)
        result = run_compiled_binary

        it "is correct" do
          # 3. compile the Java program
          compile_java_test(test_files)

          # 4. execute the Java program
          is_dir = File.directory?(test_case)
          java_result = run_java_binary(test_case_name, is_dir)

          result.should eq java_result

          # optimization: cache the results of the java programs, as they are
          # unchanging. They can be storing... somewhere.
        end
      end
    end
  end
end
