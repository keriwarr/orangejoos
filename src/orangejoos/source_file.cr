# A SourceFile represents a file containing source code to be compiled and eventually linked. As the
# pipeline runs the data is modified to
class SourceFile
  property! tokens : Array(Lexeme)
  property! parse_tree : ParseTree
  property! ast : AST::File

  getter! path : String
  getter! contents : String

  def initialize(@path : String)
  end

  def read!
    @contents = File.read(path)
    return contents
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
    case stage
    when Stage::SCAN     then data_type = "lexemes";                     data = @tokens
    when Stage::PARSE    then data_type = "parse tree";                  data = @parse_tree.as?(ParseTree).try &.pprint(0)
    when Stage::SIMPLIFY then data_type = "abstract syntax tree";        data = @ast.as?(AST::File).try &.pprint(0)
    when Stage::WEED     then data_type = "weeded abstract syntax tree"; data = @ast.as?(AST::File).try &.pprint(0)
    end
    STDERR.puts "=== FILE #{data_type}: #{@path} ===\n#{data}"
  end
end
