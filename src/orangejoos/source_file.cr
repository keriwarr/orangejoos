# A SourceFile represents a file containing source code to be compiled and eventually linked. As the
# pipeline runs the data is modified to
class SourceFile
  property! tokens : Array(Lexeme)
  property! parse_tree : ParseTree
  property! ast : AST::File

  getter! path : String
  getter! contents : String

  property! single_type_imports : Array(String)
  property! on_demand_imports : Array(String)
  property! system_imports : Array(String)

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
    return if @path.try &.includes?("/stdlib/") && @path.try &.includes?("/java/")

    print_sections : Array({data_type: String, data: String | Nil}) = [] of {data_type: String, data: String | Nil}

    case stage
    when Stage::SCAN     then print_sections.push({data_type: "lexemes",                     data: @tokens.to_s})
    when Stage::PARSE    then print_sections.push({data_type: "parse tree",                  data: @parse_tree.as?(ParseTree).try &.pprint(0)})
    when Stage::SIMPLIFY then print_sections.push({data_type: "abstract syntax tree",        data: @ast.as?(AST::File).try &.pprint(0)})
    when Stage::WEED     then print_sections.push({data_type: "weeded abstract syntax tree", data: @ast.as?(AST::File).try &.pprint(0)})
    when Stage::NAME_RESOLUTION
      print_sections.push({data_type: "single type imports", data: @single_type_imports.try &.join("\n")})
      print_sections.push({data_type: "on demand imports", data: @on_demand_imports.try &.join("\n")})
      print_sections.push({data_type: "system imports", data: @system_imports.try &.join("\n")})
    end
    print_sections.each { |s| STDERR.puts "=== #{s[:data_type]}: #{@path} ===\n#{s[:data]}\n\nqq" }
  end
end
