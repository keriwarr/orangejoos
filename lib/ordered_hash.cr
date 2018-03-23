class OrderedHash(K, V)
  def initialize
    @arr = [] of K
    @dict = Hash(K, V).new
  end

  def push(k : K, v : V)
    @arr.push(k)
    @dict[k] = v
    return
  end

  def pop : V
    k = @arr.shift # a queue, use `.pop` for a stack
    v = @dict[k]
    @dict.delete(k)
    return v
  end

  def [](k : K) : V
    return self.fetch(k)
  end

  def fetch(k : K, default) : V
    return @dict.fetch(k, default)
  end

  def fetch(k : K) : V
    return @dict.fetch(k)
  end

  def includes?(k : K) : Bool
    return @dict.includes?(k)
  end
end
