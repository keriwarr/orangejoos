# Static Analysis perfoms checks about the validity of the code that can be
# done at compile time.
class StaticAnalysis
  def initialize(@file : SourceFile)
  end

  def analyze
    @file.ast = @file.ast.accept(ConstantFoldingVisitor.new(@file.import_namespace))
    @file.ast.accept(Reachability::ReachabilityVisitor.new)
  end
end

class ConstantFoldingVisitor < Visitor::GenericMutatingVisitor
  def initialize(@namespace : ImportNamespace)
  end

  # Remove parenthesization
  def visit(node : AST::ParenExpr) : AST::Expr
    return node.expr.accept(self)

    # no super
  end

  def visit(node : AST::ExprOp) : AST::Expr
    initial_type = node.get_type(@namespace)
    original_node = node

    # We execute `super` immediately so that folding occurs from the leaves of
    # the AST up to the root of an expression sub-tree. Thus if an apparently
    # reducible expression contains sub-expressions which can't be reduced,
    # reduction will fail at the leaves and the failure will propogate upwards
    # before any mutation is done.
    # If super doesn't return an ExprOp, something very strange has happened.
    node = super.as(AST::ExprOp)

    new_node = (
      case {node.operands[0]?, node.operands[1]?}
      when {AST::ConstBool, AST::ConstBool}
        op1 = node.operands[0].as(AST::ConstBool).val
        op2 = node.operands[1].as(AST::ConstBool).val

        case node.op
        when "==" then AST::ConstBool.new(op1 == op2)
        when "!=" then AST::ConstBool.new(op1 != op2)
        when "||" then AST::ConstBool.new(op1 || op2)
        when "&&" then AST::ConstBool.new(op1 && op2)
        when "&"  then AST::ConstBool.new(op1 & op2)
        when "|"  then AST::ConstBool.new(op1 | op2)
        when "^"  then AST::ConstBool.new(op1 ^ op2)
        else           node
        end
      when {AST::ConstInteger, AST::ConstInteger}
        op1 = node.operands[0].as(AST::ConstInteger).val
        op2 = node.operands[1].as(AST::ConstInteger).val

        case node.op
        when "==" then AST::ConstBool.new(op1 == op2)
        when "!=" then AST::ConstBool.new(op1 != op2)
        when "<"  then AST::ConstBool.new(op1 < op2)
        when ">"  then AST::ConstBool.new(op1 > op2)
        when "<=" then AST::ConstBool.new(op1 <= op2)
        when ">=" then AST::ConstBool.new(op1 >= op2)
        when "+"  then AST::ConstInteger.new(op1 + op2)
        when "-"  then AST::ConstInteger.new(op1 - op2)
        when "*"  then AST::ConstInteger.new(op1 * op2)
        when "/"  then AST::ConstInteger.new(op1.tdiv(op2))
        when "%"  then AST::ConstInteger.new(op1 % op2)
        else           node
        end
      when {AST::ConstBool, Nil}
        op1 = node.operands[0].as(AST::ConstBool).val

        case node.op
        when "!" then AST::ConstBool.new(!op1)
        else          node
        end
      when {AST::ConstInteger, Nil}
        op1 = node.operands[0].as(AST::ConstInteger).val

        case node.op
        when "+" then node.operands[0]
        when "-" then AST::ConstInteger.new(-op1)
        else          node
        end
      else
        node
      end
    )

    new_type = new_node.get_type(@namespace)

    if initial_type != new_type
      raise StaticAnalysisError.new(
        "Type of Expr node changed during constant folding: #{node.inspect}"
      )
    end

    new_node.original = original_node
    return new_node
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

    # Convenience method for taking logical OR of this enum.
    def self.|(other : Reachability)
      if self == Reachability.MAYBE || other == Reachability.MAYBE
        return Reachability.MAYBE
      else
        return Reachability.NO
      end
    end
  end

  # Performs all Reachability checks on the AST.
  class ReachabilityVisitor < Visitor::GenericVisitor
    property in_set = Hash(AST::Stmt, Reachability).new
    property out_set = Hash(AST::Stmt, Reachability).new

    def handle_stmt_sequence(
      stmts : Array(AST::Stmt),
      initial_out_value : Reachability
    ) : Nil
      previous_out_value = initial_out_value
      stmts.each do |stmt|
        in_set[stmt] = previous_out_value
        stmt.accept(self)
        previous_out_value = out_set[stmt]
      end
    end

    def visit(node : AST::MethodDecl) : Nil
      # Edge case, where the body is absent or empty.
      if node.body? && node.body.size == 0 && node.typ? && !node.is_abstract?
        raise StaticAnalysisError.new(
          "Method #{node.name} missing return statment of type " \
          "#{node.typ.to_s}"
        )
      elsif !node.body? || node.body.size == 0
        # Nothing to do here.
        return
      end

      handle_stmt_sequence(node.body, Reachability::MAYBE)

      if node.typ? && out_set[node.body.last] != Reachability::NO
        raise StaticAnalysisError.new(
          "Method #{node.name} missing return statment of type " \
          "#{node.typ.to_s}"
        )
      end

      # no super
    end

    def visit(node : AST::ConstructorDecl) : Nil
      if node.body.size == 0
        return
      end

      handle_stmt_sequence(node.body, Reachability::MAYBE)

      # no super
    end

    # We don't visit all expressions, but for those that we do
    # (such as assignment expressions in blocks), forward the reachability on.
    def visit(node : AST::Expr) : Nil
      out_set[node] = in_set[node] if in_set[node]?

      # no super
    end

    # -------------------- STATEMENT VISITORS --------------------
    # Each of the below visit methods handles a distinct class of Statement.
    # All Classes of Statements must be explicitly handled.
    # Each such visit method has the guarantee that in_set[node] is
    # already set. Furthermore, each such visit method MUST set in_set for
    # all of it's child Statements before calling super.
    # Furthermore each such visit method MUST set out_set[node] for itself
    # before returning.
    # ------------------------------------------------------------

    def visit(node : AST::Block) : Nil
      if node.stmts.size == 0
        out_set[node] = in_set[node]
        return
      end

      handle_stmt_sequence(node.stmts, in_set[node])

      out_set[node] = out_set[node.stmts.last]

      # no super
    end

    def visit(node : AST::ForStmt | AST::WhileStmt) : Nil
      expr = node.expr.as?(AST::ConstBool)

      if node.as?(AST::ForStmt).try &.init?
        in_set[node.as(AST::ForStmt).init] = in_set[node]
      end
      if node.as?(AST::ForStmt).try &.update?
        in_set[node.as(AST::ForStmt).update] = in_set[node]
      end

      if expr.try &.val == true
        in_set[node.body] = in_set[node]
      elsif expr.try &.val == false
        in_set[node.body] = Reachability::NO
      else
        in_set[node.body] = in_set[node]
      end

      super

      if expr.try &.val == true
        out_set[node] = Reachability::NO
      elsif expr.try &.val == false
        out_set[node] = in_set[node]
      else
        out_set[node] = in_set[node]
      end
    end

    # If statements are a weird case and defy expectation. See JLS 14.20 for
    # more details.
    def visit(node : AST::IfStmt) : Nil
      in_set[node.if_body] = in_set[node]
      in_set[node.else_body] = in_set[node] if node.else_body?

      super

      if node.else_body?
        out_set[node] = out_set[node.if_body] | out_set[node.else_body]
      else
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
      raise Exception.new(
        "ReachabilityVisitor must, but did not, explicitly visit statement: " \
        "#{node.inspect}"
      )
    end

    def on_completion
      in_set.each do |stmt, reachable|
        if reachable != Reachability::MAYBE
          raise StaticAnalysisError.new(
            "Unreachable statment: #{stmt.inspect}"
          )
        end
      end
    end
  end
end
