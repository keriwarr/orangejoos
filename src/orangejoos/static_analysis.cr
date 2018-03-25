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
  SUPPORTED_OPERATORS = ["||", "&&", "==", "+", "*", "-", "/"]

  # Remove parenthisization
  def visit(node : AST::ParenExpr) : AST::Expr
    return node.expr.accept(self)
  end

  def visit(node : AST::ExprOp) : AST::Expr
    return node if !SUPPORTED_OPERATORS.includes?(node.op)

    # We execute `super` immediately so that folding occurs form the leaves of the AST
    # up to the root of an expression sub-tree
    # Thus is an apprently reducible expression contains sub-expressions which can't be
    # reduced. Reduction will fail at the leaves, and the failure will propogate upwards
    # before any mutation is done.
    node = super.as(AST::ExprOp) # If super doesn't return an ExprOp, something very strange has happened
    op1 = node.operands[0]
    op2 = node.operands[1]
    op1bool = op1.as?(AST::ConstBool)
    op2bool = op2.as?(AST::ConstBool)
    op1int = op1.as?(AST::ConstInteger)
    op2int = op2.as?(AST::ConstInteger)

    begin
      op1val = op1int.try(&.val.to_i32)
      op2val = op2int.try(&.val.to_i32)
    rescue ArgumentError
      raise Exception.new("Const Integers contained invalid values")
    end

    case node.op
    when "||"
      if op1bool.try &.val == "false" && op2bool.try &.val == "false"
        AST::ConstBool.new("false")
      elsif op1bool && op2bool
        AST::ConstBool.new("true")
      else
        node
      end
    when "&&"
      if op1bool.try &.val == "true" && op2bool.try &.val == "true"
        AST::ConstBool.new("true")
      elsif op1bool && op2bool
        AST::ConstBool.new("false")
      else
        node
      end
    when "=="
      if op1bool.try &.val == "true" && op2bool.try &.val == "true"
        AST::ConstBool.new("true")
      elsif op1bool.try &.val == "false" && op2bool.try &.val == "false"
        AST::ConstBool.new("true")
      elsif op1bool && op2bool
        AST::ConstBool.new("false")
      elsif op1int && op2int && op1int.val == op2int.val
        AST::ConstBool.new("true")
      elsif op1int && op2int
        AST::ConstBool.new("false")
      else
        node
      end
    when "+"
      if op1val && op2val
        AST::ConstInteger.new((op1val + op2val).to_s) # Integer overflow may happen here and that is expected
      else
        node
      end
    when "-"
      if op1val && op2val
        AST::ConstInteger.new((op1val - op2val).to_s) # Integer underflow may happen here and that is expected
      else
        node
      end
    when "*"
      if op1val && op2val
        AST::ConstInteger.new((op1val * op2val).to_s) # Integer overflow may happen here and that is expected
      else
        node
      end
    when "/"
      if op1val && op2val
        AST::ConstInteger.new((op1val / op2val).to_s) # Integer rounding may happen here and that is expected
      else
        node
      end
    else
      raise Exception.new("supported operator not handled by case statement")
    end
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

    # Convenience method for taking logical OR of this enum
    def self.|(other : Reachability)
      if self == Reachability.MAYBE || other == Reachability.MAYBE
        return Reachability.MAYBE
      else
        return Reachability.NO
      end
    end
  end

  # Performs all Reachability checks on the AST
  class ReachabilityVisitor < Visitor::GenericVisitor
    property in_set = Hash(AST::Stmt, Reachability).new
    property out_set = Hash(AST::Stmt, Reachability).new

    def handle_stmt_sequence(stmts : Array(AST::Stmt)) : Nil
      previous_out_value = Reachability::MAYBE # Bootstrap the loop. First statement of a block is never unreachable
      stmts.each do |stmt|
        in_set[stmt] = previous_out_value
        stmt.accept(self)
        previous_out_value = out_set[stmt]
      end
    end

    def visit(node : AST::MethodDecl) : Nil
      # FIXME: By this stage, node.body should never be Nil but for some
      # reason it sometimes is
      # If it's empty we perform this edge-case check
      if node.body? && node.body.size == 0 && node.typ?
        raise StaticAnalysisError.new("Method #{node.name} missing return statment of type #{node.typ.to_s}")
      elsif !node.body? || node.body.size == 0
        # Nothing to do here
        return
      end

      handle_stmt_sequence(node.body)

      if node.typ? && out_set[node.body.last] != Reachability::NO
        raise StaticAnalysisError.new("Method #{node.name} missing return statment of type #{node.typ.to_s}")
      end

      # no super
    end

    def visit(node : AST::ConstructorDecl) : Nil
      if node.body.size == 0
        return
      end

      handle_stmt_sequence(node.body)

      # no super
    end

    # We don't visit all expressions, but for those that we do
    # (such as assignment expressions in blocks), forward the reachability on.
    def visit(node : AST::Expr) : Nil
      out_set[node] = in_set[node] if in_set[node]?

      # no super
    end

    # ------------------- STATEMENT VISITORS -------------------
    # Each of the below visit methods handles a distinct class of Statement.
    # All Classes of Statements must be explicitly handled.
    # Each such visit method has the guarantee that in_set[node] is
    # already set. Furthermore, each such visit method MUST set in_set for
    # all of it's child Statements before calling super.
    # Furthermore each such visit method MUST set out_set[node] for itself
    # before returning.
    # ----------------------------------------------------------

    def visit(node : AST::Block) : Nil
      if node.stmts.size == 0
        out_set[node] = in_set[node]
        return
      end

      handle_stmt_sequence(node.stmts)

      out_set[node] = out_set[node.stmts.last]

      # no super
    end

    def visit(node : AST::ForStmt | AST::WhileStmt) : Nil
      expr = node.expr.as?(AST::ConstBool)

      in_set[node.init] = in_set[node] if node.responds_to?(:init?) && node.init?
      in_set[node.update] = in_set[node] if node.responds_to?(:update?) && node.update?

      if expr.try &.val == "true"
        in_set[node.body] = in_set[node]
      elsif expr.try &.val == "false"
        in_set[node.body] = Reachability::NO
      else
        in_set[node.body] = in_set[node]
      end

      super

      if expr.try &.val == "true"
        out_set[node] = Reachability::NO
      elsif expr.try &.val == "false"
        out_set[node] = in_set[node]
      else
        out_set[node] = in_set[node]
      end
    end

    # If statements are a weird case and defy expectation. See JLS 14.20 for more details
    def visit(node : AST::IfStmt) : Nil
      # Not a mistake
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
