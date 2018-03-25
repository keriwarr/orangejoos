# Static Analysis perfoms checks about the validity of the code that can be done at compile time
class StaticAnalysis
  def initialize(@file : SourceFile)
  end

  def analyze
    @file.ast = @file.ast.accept(ConstantFoldingVisitor.new)
    @file.ast.accept(Reachability::ReachabilityVisitor.new)
  end
end

class ConstantFoldingVisitor < Visitor::GenericMutatingVisitor
  def visit(node : AST::ParenExpr) : AST::Node
    return node.expr.accept(self)
  end

  def visit(node : AST::ExprOp) : AST::Node
    case node.op
    when "||"
      node = super
      if !node.is_a?(AST::ExprOp)
        return node
      end
      exprop = node.as(AST::ExprOp)
      if exprop.operands.size != 2 || !exprop.operands[0].is_a?(AST::ConstBool) || !exprop.operands[1].is_a?(AST::ConstBool)
        return node
      end
      if exprop.operands[0].as(AST::ConstBool).val == "false" && exprop.operands[1].as(AST::ConstBool).val == "false"
        node = AST::ConstBool.new("false")
      else
        node = AST::ConstBool.new("true")
      end
    when "&&"
      node = super
      if !node.is_a?(AST::ExprOp)
        return node
      end
      exprop = node.as(AST::ExprOp)
      if exprop.operands.size != 2 || !exprop.operands[0].is_a?(AST::ConstBool) || !exprop.operands[1].is_a?(AST::ConstBool)
        return node
      end
      if exprop.operands[0].as(AST::ConstBool).val == "true" && exprop.operands[1].as(AST::ConstBool).val == "true"
        node = AST::ConstBool.new("true")
      else
        node = AST::ConstBool.new("false")
      end
    when "=="
      node = super
      if !node.is_a?(AST::ExprOp) || node.as(AST::ExprOp).operands.size != 2
        return node
      end

      exprop = node.as(AST::ExprOp)
      op1 = exprop.operands[0]
      op2 = exprop.operands[1]

      if op1.as?(AST::ConstBool).try &.val == "true" && op2.as?(AST::ConstBool).try &.val == "true"
        node = AST::ConstBool.new("true")
      elsif op1.as?(AST::ConstBool).try &.val == "false" && op2.as?(AST::ConstBool).try &.val == "false"
        node = AST::ConstBool.new("true")
      elsif op1.is_a?(AST::ConstBool) && op2.is_a?(AST::ConstBool)
        node = AST::ConstBool.new("false")
      elsif op1.is_a?(AST::ConstInteger) && op2.is_a?(AST::ConstInteger)
        if op1.as(AST::ConstInteger).val == op2.as(AST::ConstInteger).val
          node = AST::ConstBool.new("true")
        else
          node = AST::ConstBool.new("false")
        end
      end
    when "+", "-", "*", "/"
      node = super
      if !node.is_a?(AST::ExprOp) || node.as(AST::ExprOp).operands.size != 2
        return node
      end

      exprop = node.as(AST::ExprOp)
      op1 = exprop.operands[0]
      op2 = exprop.operands[1]

      if !op1.is_a?(AST::ConstInteger) || !op2.is_a?(AST::ConstInteger)
        return node
      end

      case exprop.op
      when "+"
        .to_s
        node = AST::ConstInteger.new((op1.as(AST::ConstInteger).val.to_i + op2.as(AST::ConstInteger).val.to_i).to_s)
      when "-"
        node = AST::ConstInteger.new((op1.as(AST::ConstInteger).val.to_i - op2.as(AST::ConstInteger).val.to_i).to_s)
      when "*"
        node = AST::ConstInteger.new((op1.as(AST::ConstInteger).val.to_i * op2.as(AST::ConstInteger).val.to_i).to_s)
      when "/"
        node = AST::ConstInteger.new((op1.as(AST::ConstInteger).val.to_i / op2.as(AST::ConstInteger).val.to_i).to_s)
      end
    end

    return node
  end
end

# This module owns everything to do with determining whether code is reachable
# especially, throwing an error if not.
module Reachability
  # It is not sensible to speak of code as definitely reachable. Instead,
  # we will look for cases where it is definitely NOT reachable.
  enum Reachability
    NO
    MAYBE

    def self.|(other : Reachability)
      return Reachability.MAYBE if self == Reachability.MAYBE || other == Reachability.MAYBE
      return Reachability.NO
    end
  end

  # Performs all Reachability checks on the AST
  class ReachabilityVisitor < Visitor::GenericVisitor
    property in_set = Hash(AST::Stmt, Reachability).new
    property out_set = Hash(AST::Stmt, Reachability).new

    def visit(node : AST::MethodDecl) : Nil
      if !node.body? || node.body.size == 0
        if node.body? && node.typ?
          raise StaticAnalysisError.new("Method #{node.name} missing return statment of type #{node.typ.to_s}")
        end
        return
      end

      previous_out_value = Reachability::MAYBE # Bootstrap the loop. First statement of a method is never unreachable
      node.body.each do |stmt|
        in_set[stmt] = previous_out_value
        stmt.accept(self)
        previous_out_value = out_set[stmt]
      end

      if node.typ? && out_set[node.body.last] != Reachability::NO
        raise StaticAnalysisError.new("Method #{node.name} missing return statment of type #{node.typ.to_s}")
      end

      # no super
    end

    def visit(node : AST::ConstructorDecl) : Nil
      if node.body.size == 0
        return
      end

      previous_out_value = Reachability::MAYBE # Bootstrap the loop. First statement of a method is never unreachable
      node.body.each do |stmt|
        in_set[stmt] = previous_out_value
        stmt.accept(self)
        previous_out_value = out_set[stmt]
      end

      # no super
    end

    # We don't actually visit all expressions, but for those that we do
    # (such as assignment expressions in blocks), forward the reachability on.
    def visit(node : AST::Expr) : Nil
      if in_set[node]?
        out_set[node] = in_set[node]
      end

      # no super
    end

    def visit(node : AST::Block) : Nil
      if node.stmts.size == 0
        out_set[node] = in_set[node]
        return
      end

      previous_out_value = in_set[node]
      node.stmts.each do |stmt|
        in_set[stmt] = previous_out_value
        stmt.accept(self)
        previous_out_value = out_set[stmt]
      end

      out_set[node] = out_set[node.stmts.last]

      # no super
    end

    def visit(node : AST::ForStmt) : Nil
      in_set[node.init] = in_set[node] if node.init?
      in_set[node.update] = in_set[node] if node.update?

      if node.expr.is_a?(AST::ConstBool) && node.expr.as(AST::ConstBool).val == "true"
        in_set[node.body] = in_set[node]
      elsif node.expr.is_a?(AST::ConstBool) && node.expr.as(AST::ConstBool).val == "false"
        in_set[node.body] = Reachability::NO
      else
        # TODO: what to do here?
        in_set[node.body] = in_set[node]
      end
      super
      if node.expr.is_a?(AST::ConstBool) && node.expr.as(AST::ConstBool).val == "true"
        out_set[node] = Reachability::NO
      elsif node.expr.is_a?(AST::ConstBool) && node.expr.as(AST::ConstBool).val == "false"
        out_set[node] = in_set[node]
      else
        # TODO: what to do here?
        out_set[node] = in_set[node]
      end
    end

    def visit(node : AST::WhileStmt) : Nil
      if node.expr.is_a?(AST::ConstBool) && node.expr.as(AST::ConstBool).val == "true"
        in_set[node.body] = in_set[node]
      elsif node.expr.is_a?(AST::ConstBool) && node.expr.as(AST::ConstBool).val == "false"
        in_set[node.body] = Reachability::NO
      else
        # TODO: what to do here?
        in_set[node.body] = in_set[node]
      end
      super
      if node.expr.is_a?(AST::ConstBool) && node.expr.as(AST::ConstBool).val == "true"
        out_set[node] = Reachability::NO
      elsif node.expr.is_a?(AST::ConstBool) && node.expr.as(AST::ConstBool).val == "false"
        out_set[node] = in_set[node]
      else
        # TODO: what to do here?
        out_set[node] = in_set[node]
      end
    end

    # If statements are a weird case and defy expectation. See JLS 14.20 for more details
    def visit(node : AST::IfStmt) : Nil
      in_set[node.if_body] = in_set[node]
      in_set[node.else_body] = in_set[node] if node.else_body?
      super
      if node.else_body?
        out_set[node] = out_set[node.if_body] | out_set[node.else_body]
      else
        # Not a mistake
        out_set[node] = in_set[node]
      end
    end

    def visit(node : AST::VarDeclStmt) : Nil
      out_set[node] = in_set[node]

      # no super
    end

    def visit(node : AST::ReturnStmt) : Nil
      out_set[node] = Reachability::NO

      # no super
    end

    def visit(node : AST::Stmt) : Nil
      raise Exception.new("ReachabilityVisitor must, but did not, explicitly visit all Statements")
    end

    def on_completion
      in_set.each do |stmt, reachable|
        if reachable != Reachability::MAYBE
          raise StaticAnalysisError.new("Unreachable statment of type #{typeof(stmt)}")
        end
      end
    end
  end
end
