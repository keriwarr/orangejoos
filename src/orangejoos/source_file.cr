# A SourceFile represents a file containing source code to be compiled and eventually linked. As the
# pipeline runs the data is modified to

require "./ast_printer"

class SourceFile
  property! tokens : Array(Lexeme)
  property! parse_tree : ParseTree
  property! ast : AST::File

  getter! path : String
  getter! contents : String

  property! same_file_imports : Array(String)
  property! single_type_imports : Array(String)
  property! same_package_imports : Array(String)
  property! on_demand_imports : Array(String)
  property! system_imports : Array(String)

  property! import_namespace : ImportNamespace

  property! code : CodeFile

  def initialize(@path : String)
  end

  def read!
    @contents = File.read(path)
    return contents
  end

  def attempt
    yield(self)
  rescue ex : CompilerError
    ex.file = self.path
    raise ex
  end

  # The type name that this file is allowed to export.
  # - If the file has a hyphen or any special characters, they become
  #   underscores.
  # - If the filename is a keyword, append an underscore. (May not be
  #   relevant, only for packages).
  # - If the filename starts with a digit add an underscore prefix.
  def class_name
    if /\.jav$/ =~ path
      filename = File.basename(path, ".jav")
    else
      filename = File.basename(path, ".java")
    end

    # If the name starts with a number, prefix it with an underscore.
    filename = "_" + filename if filename[0].ascii_number?

    # Replace all invalid name characters with underscores. Only ascii
    # letters, numbers, '$', and '_' are considered valid.
    cleaned_filename = ""
    # new_word = true
    filename.chars.each do |c|
      if c.ascii_letter?
        # if new_word
        #   new_word = false
        #   cleaned_filename += c.upcase
        # else
        cleaned_filename += c
        # end
      elsif c.ascii_number? || c == '$' || c == '_'
        # new_word = true
        cleaned_filename += c
      else
        # new_word = true
        cleaned_filename += "_"
      end
    end

    return cleaned_filename
  end

  def debug_print(stage : Stage)
    return if @path.try &.includes?("/stdlib/") && @path.try &.includes?("/java/")

    case stage
    when Stage::SCAN
      STDERR.puts "=== lexemes: #{@path} ===\n#{@tokens.to_s}\n\n"
    when Stage::PARSE
      STDERR.puts "=== parse tree: #{@path} ===\n#{@parse_tree.as?(ParseTree).try &.pprint(0)}\n\n"
    when Stage::SIMPLIFY
      STDERR.puts "=== abstract syntax tree: #{@path} ===\n\n"
      @ast.as?(AST::File).try &.accept(AST::ASTPrinterVisitor.new)
      STDERR.puts ""
    when Stage::WEED
      STDERR.puts "=== weeded abstract syntax tree: #{@path} ===\n\n"
      @ast.as?(AST::File).try &.accept(AST::ASTPrinterVisitor.new)
      STDERR.puts ""
    when Stage::NAME_RESOLUTION
      STDERR.puts "=== same file imports: #{@path} ===\n#{@same_file_imports.try &.join("\n")}\n\n"
      STDERR.puts "=== single type imports: #{@path} ===\n#{@single_type_imports.try &.join("\n")}\n\n"
      STDERR.puts "=== same pack imports: #{@path} ===\n#{@same_package_imports.try &.join("\n")}\n\n"
      STDERR.puts "=== on demand imports: #{@path} ===\n#{@on_demand_imports.try &.join("\n")}\n\n"
      # STDERR.puts "=== system imports: #{@path} ===\n#{@system_imports.try &.join("\n")}\n\n"
    end
  end
end
