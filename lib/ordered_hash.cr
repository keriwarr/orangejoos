class OrderedHash(K, V)
  def initialize
    @arr = [] of K
    @dict = Hash(K, V).new
    @index_dict = Hash(K, Int32).new
  end

  def push(k : K, v : V)
    # Delete the previous value from the ordering if it is overwritten.
    @arr.delete_at(@index_dict[k]) if @dict.has_key?(k)
    @arr.push(k)
    @dict[k] = v
    @index_dict[k] = @arr.size - 1
    return
  end

  # Pops the oldest item in the `OrderedHash`.
  def pop : V
    k = @arr.shift # a queue, use `.pop` for a stack
    v = @dict[k]
    @dict.delete(k)
    return v
  end

  def [](k : K) : V
    return @dict[k]
  end

  def []?(k : K) : V?
    return @dict[k]?
  end

  def fetch(k : K, default) : V
    return @dict.fetch(k, default)
  end

  def fetch(k : K) : V
    return @dict.fetch(k)
  end

  def has_key?(k : K) : Bool
    return @dict.has_key?(k)
  end

  # Iterates through the dictionary in order.
  def each(&block : (K, V) -> _)
    @arr.each do |k|
      yield(k, @dict[k])
    end
  end

  def size : Int32
    @dict.size
  end
end
