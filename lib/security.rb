class Security
  attr_reader :symbol, :price
  def initialize(symbol, price)
    @symbol, @price = symbol, price
  end

  # A "mid price" is not a typical convention, but should be something
  # like the average bid/ask spread, adjusted for open interest.
  def mid_price
    price
  end
end
