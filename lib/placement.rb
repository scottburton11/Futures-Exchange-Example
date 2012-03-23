require 'eventmachine'
require 'em-zeromq'
require 'logger'

# OrderReceiver handles incoming TCP connections and slices them
# into discrete orders. This would be a good place to reject bad
# data.
#
# It then shoves individual order strings, one per newline, into a
# ZeroMQ Push socket, which can feed 1 or more Fulfillment services.
#
# We pass in a logger and a ZMQ socket so they can be reused; this 
# OrderReceiver will be instantiated every time a TCP connection is 
# initiated, and I think we can't have multiple open PUSH sockets at
# at time.
class OrderReceiver < EM::Connection

  attr_reader :publisher, :logger
  def initialize(*args)
    super
    @publisher = args[0]
    @logger = args[1]
    @buffer = ""
  end

  def post_init
    logger.info "Connection initiated"
  end

  def receive_data data
    @buffer << data
    while msg = @buffer.slice!(/(.+)\n/)
      publisher.send_msg msg
    end
  end
end

logger = Logger.new("logs/development.log")

EM.run do
  context = EM::ZeroMQ::Context.new(1)
  path = File.expand_path(File.join(File.expand_path(__FILE__), "..", "..", "tmp", "orders.sock"))
  socket = context.bind(ZMQ::PUSH, "ipc://#{path}")
  EM.start_server "127.0.0.1", 9001, OrderReceiver, socket, logger
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
end
