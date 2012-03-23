require 'eventmachine'
require 'em-zeromq'
require 'em-redis'
require 'logger'

logger = Logger.new("logs/development.log")
OrderRegex = /^(bid|ask):(\w+):([\d\.]+):(\d+):(.+)/

# OrderHandler coordinates messages pulled off the ZeroMQ PULL socket,
# dropping invalid orders, and instantiating good ones. It then
# instantiates a Fulfillment instance to attempt to fill the order.
class OrderHandler

  attr_reader :redis, :logger
  def initialize(logger = Logger.new(STDOUT), redis = EM::Protocols::Redis.connect)
    @redis  = redis
    @logger = logger
    @redis = redis
  end

  def on_readable(socket, parts)
    parts.each_with_index do |part, index|
      str = part.copy_out_string
      unless str =~ OrderRegex
        logger.warn "invalid order: #{str}"
        next
      end
      logger.info "Handling order: #{str}"
      order = Order.from_string(str)
      fulfillment = Fulfillment.new(order, redis, logger)
      fulfillment.handle
    end
  end
end

class Order < Struct.new(:security, :price, :quantity, :customer_id)
  include EM::Deferrable
  def self.from_string(str)
    match = str.match OrderRegex
    Object.const_get(match[1].capitalize).new(match[2], match[3].to_f, match[4].to_i, match[5])
  end

  def key
    [order_type, security, price].join(":")
  end

  def opposite_key
    [opposite_type, security, price].join(":")
  end

  def to_s
    [order_type, security, price, quantity, customer_id].join(":")
  end

  def value
    price * quantity
  end

  def value_cents
    (value * 100).to_i
  end
end

class Ask < Order
  def order_type
    :ask
  end

  def opposite_type
    :bid
  end

  def settle(matching_order, redis)
    redis.incrby [:balance, customer_id].join(":"), value_cents do |response|
      yield response if block_given?
    end
  end
end

class Bid < Order
  def order_type
    :bid
  end

  def opposite_type
    :ask
  end

  def settle(matching_order, redis)
    redis.decrby [:balance, customer_id].join(":"), value_cents do |response|
      yield response if block_given?
    end
  end
end


# Fulfillment tries to find a matching order for incoming orders, by popping any
# orders off of an array of matching opposite orders, in FIFO order:
#
# bid:AAPL:600 -> ask:AAPL:600
# 
# If an order exists that can fill the incoming order, a Settlement is created for
# the pair.
#
# Since this is an atomic operation, we can run this service in parallel.
class Fulfillment

  attr_reader :order, :redis, :logger
  def initialize(order, redis = EM::Protocols::Redis.connect, logger = Logger.new(STDOUT))
    @order = order
    @redis = redis
    @logger = logger
  end

  def handle
    redis.rpop(order.opposite_key) do |response|
      if response
        fill_with(Order.from_string(response))
      else
        place_order
      end
    end
  end

  def place_order
    redis.lpush(order.key, order.to_s)
  end

  def fill_with(matching_order)
    logger.info "Matched #{order.to_s} -> #{matching_order.to_s}"
    settlement = Settlement.new(order, matching_order, redis)
    settlement.settle
    settlement.callback { |response| logger.info "Filled #{order.order_type} #{order.security} at $#{order.price} for customer #{order.customer_id}."}
    settlement.errback  {logger.info "There was a problem filling order #{order.to_s} with #{matching_order.to_s}."}
  end
end

# Settlement is a simple Deferrable that tries to arrange a settlement for
# an order pair. A settlement will credit the seller and debit the buyer.
# 
# It would be more clear if we were doing the work here - should an order really
# settle itself?
class Settlement
  include EM::Deferrable

  attr_reader :order, :matching_order, :redis
  def initialize(order, matching_order, redis)
    @order, @matching_order, @redis = order, matching_order, redis
  end

  def settle
    order.settle(matching_order, redis) do |response|
      if response
        succeed
      else
        fail
      end
    end
  end
end

EM.run do
  path = File.expand_path(File.join(File.expand_path(__FILE__), "..", "..", "tmp", "orders.sock"))

  context = EM::ZeroMQ::Context.new(1)
  socket = context.connect(ZMQ::PULL, "ipc://#{path}", OrderHandler.new(Logger.new("logs/development.log")))
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
end
