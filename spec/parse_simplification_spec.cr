require "./spec_helper"
require "../src/orangejoos/parser"
require "../src/orangejoos/parse_tree"

describe ParseSimplification do
  describe "#flatten" do
    it "flattens expression trees" do
      # Test case tree:
      #    AndExpression
      #      EqualityExpression
      #        RelationalExpression
      #          AdditiveExpression
      #            1
      #            +
      #            3
      tree = ParseTree.new("AndExpression", [
        ParseTree.new("EqualityExpression", [
          ParseTree.new("RelationalExpression", [
            ParseTree.new("AdditiveExpression", [
              Lexeme.new(Type::NumberLiteral, 1, "1").as(ParseNode),
              Lexeme.new(Type::Operator, 1, Operator::SUB).as(ParseNode),
              Lexeme.new(Type::NumberLiteral, 1, "3").as(ParseNode),
            ]).as(ParseNode)
          ]).as(ParseNode)
        ]).as(ParseNode)
      ])

      # Attempt to flatten the tree.
      result = ParseSimplification.flatten_tree(tree)
      result.name.should eq "AdditiveExpression"
      result.tokens.size.should eq 3
      result.tokens.to_a[0].as(Lexeme).sem.should eq "1"
      result.tokens.to_a[1].as(Lexeme).sem.should eq "-"
      result.tokens.to_a[2].as(Lexeme).sem.should eq "3"
    end
  end
end
