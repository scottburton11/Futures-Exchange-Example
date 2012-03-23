require 'eventmachine'
require 'securerandom'
require 'logger'
require 'em-redis'

$: << "." << "lib"

require 'participant'
require 'security'

module MarketParticipationClient
  def post_init
    redis = EM::Protocols::Redis.connect
    logger = Logger.new("logs/development.log")

    # Every second for the next periods, each of the Participants will
    # act on the market
    p = 0
    timer = EventMachine::PeriodicTimer.new(1) do
      if (p += 1) > 100
        timer.cancel
        EM.stop_event_loop
      end

      # If a participant has sufficient buying power for this
      # period (their long positions do not exceed their margin 
      # limit, currently 2x the starting amount; there is no BP limit
      # yet on short positions), they will decide to either get long or
      # short a random underlying security, or do nothing.
      #
      # A bid or ask order will be generated using a random delta of the
      # underlying's current price (which is fixed for now); this order
      # behaves like a Limit Order. A string representation of the order
      # is then sent to the Placement service via TCP.
      #
      Participants.each do |participant|
        redis.get "balance:#{participant.id}" do |response|
          participant.balance = response.to_i
          # if the balance is sufficient to place an order
          if participant.balance + participant.margin_limit > 0
            # choose to get long, get short or do nothing
            action = [:get_long, :get_short, :do_nothing][rand(3)]
            # pick a random security
            security = Securities[rand(Securities.length)]
            # generate a formatted order string
            order_string = participant.send(action, security)
            logger.info("Placing order: " + order_string) if order_string
            #place the order
            send_data(order_string + "\n") if order_string
          end
        end
      end
    end
  end
end

# Instantiate some common securities
Securities = [
  Security.new("AAPL", 600.00),
  Security.new("KYE", 27.00),
  Security.new("TIF", 73.00),
  Security.new("SLB", 75.00),
  Security.new("AMZN", 192.00),
  Security.new("HD", 49.00)
]

Participants = 100.times.map{ Participant.new }

EM.run do
  redis = EM::Protocols::Redis.connect
  # initialize balances
  Participants.each do |participant|
    redis.set "balance:#{participant.id}", participant.balance
  end

  EM.add_timer(3) do
    EventMachine.connect "127.0.0.1", 9001, MarketParticipationClient, redis
  end
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
end
