require "./spec_helper"
require "ordered_hash"

describe OrderedHash do
  it "does not duplicate same-keys in the ordering" do
    h = OrderedHash(Int32, Int32).new
    h.push(1, 2)
    h.push(1, 3)
    h.size.should eq 1
    h[1]?.should eq 3

    values = [] of Tuple(Int32, Int32)
    h.each { |k, v| values.push(Tuple.new(k, v)) }
    values.size.should eq 1
    values[0].should eq Tuple.new(1, 3)
  end

  it "correctly has ordering" do
    h = OrderedHash(Int32, Int32).new
    h.push(1, 2)
    h.push(2, 10)
    h.push(0, 20)
    h.size.should eq 3

    # Fetch the ordered list from the OrderedHash.
    values = [] of Tuple(Int32, Int32)
    h.each { |k, v| values.push(Tuple.new(k, v)) }

    expected_values = [
      Tuple(Int32, Int32).new(1, 2),
      Tuple(Int32, Int32).new(2, 10),
      Tuple(Int32, Int32).new(0, 20),
    ] of Tuple(Int32, Int32)

    values.should eq expected_values
  end
end
