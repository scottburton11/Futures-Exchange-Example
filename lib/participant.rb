class Participant
  attr_reader :id, :logger
  attr_accessor :balance
  def initialize
    @positions = []
    @balance = 1000000
    @id = SecureRandom.uuid[0..6]
    @logger = Logger.new("logs/development.log")
  end

  def margin_limit
    2000000
  end

  def get_long(security, volume=1)
    build_order(:bid, security.symbol, bid_price_for(security), volume, id)
  end

  def get_short(security, volume=1)
    build_order(:ask, security.symbol, ask_price_for(security), volume, id)
  end

  def build_order(*args)
    args.join(":")
  end

  def do_nothing(security)
    nil
  end

  # Buy low, sell high
  # Don't take any wooden nickels
  # Seabuscuit in the third
  #
  # If I am already short this security, I want the price to be lower
  # than my short position. If I am not short, I just want it to be
  # lower than the mid price.
  def bid_price_for(security)
    # check my positions for this, and determine a price
    # else
    security.mid_price - price_delta
  end

  # If I am already long this security, I want to ask higher than my
  # long position. If I am not long, I just want it to be higher than
  # the current mid price.
  def ask_price_for(security)
    # check my positions for this, and determine a price
    # else
    security.mid_price + price_delta
  end

  # TODO: these methods belong somewhere else

  # a random percentage value +/- a given threshold
  def percentage(within=3)
    (rand * 2 - 1) * within
  end

  # a random multiple of $0.25, within magnitude
  def price_delta(magnitude=20)
    rand(magnitude) * 0.25
  end
end
