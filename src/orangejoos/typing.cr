class ExprTyp
  property name : String

  def initialize(@name : String)
  end

  def ==(other : ExprTyp)
    return self.name == other.name
  end
end

module Typing
  property! expr_typ : ExprTyp

  def get_type : ExprTyp
    if self.expr_typ?
      return self.expr_typ
    end
    self.expr_typ = self.resolve_type
    return self.expr_typ
  end

  private abstract def resolve_type() : ExprTyp
end
