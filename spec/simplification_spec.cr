# require "./spec_helper"
# require "../src/orangejoos/simplification"
# require "../src/orangejoos/parse_tree"
#
# describe Simplification do
#   it "handles all production rules" do
#     lhs_rules = [] of String
#     contents = File.read("./grammar/joos1w.bnf")
#     contents.split("\n").each do |line|
#       if /[A-Za-z]+\:/ =~ line
#         lhs = /(?<lhs>^[A-Za-z]+):/.match(line).try &.["lhs"]
#         if !lhs.nil?
#           lhs_rules.push(lhs)
#         end
#       end
#     end
#
#     unimplemented_rules = [] of String
#
#     lhs_rules.each do |rule|
#       tree = ParseTree.new(rule, [] of ParseNode)
#
#       # Attempt an AST simplify.
#       begin
#         Simplification.new.simplify(tree)
#       rescue ex : UnexpectedNodeException
#         # Do nothing.
#       rescue ex : Exception
#         # Rule has been accepted.
#         next
#       else
#         # Rule has been accepted.
#         next
#       end
#
#       # Attempt an AST tree simplify.
#       begin
#         Simplification.new.simplify_tree(tree)
#       rescue ex : UnexpectedNodeException
#         # Add this rule to the unaccepted rules. It has not been
#         # accepted by either `simplify` or `simplify_tree`.
#         unimplemented_rules.push(rule)
#       rescue ex : Exception
#         # Rule has been accepted.
#         next
#       end
#     end
#
#     if unimplemented_rules.size > 0
#       puts "unimplemented rules:\n#{unimplemented_rules.join("\n")}"
#     end
#     unimplemented_rules.size.should eq 0
#   end
# end
