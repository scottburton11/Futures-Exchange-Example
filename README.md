Futures Exchange Example
========================
An example futures exchange, implemented with EventMachine, ZeroMQ and
Redis. It uses robot Market Participants to place bid (buy) and ask
(sell) orders on a set of underlying securities. Without the robots, it
should behave like a realtime market exchange.

Prerequisites
-------------
`brew install zeromq` `brew install redis`, or something of that nature.

Getting Started
---------------
`bundle`
`foreman`
`tail logs/development.log` to see what's going on.

How do Futures work?
--------------------
A _Futures Contract_ is a standardized contract between to parties to
deliver a quantity of some underlying commodity (or anything, really) at
some fixed date in the future, in exchange for money today. Buyers in a
futures exchange expect for the future market price of the underlying to
be higher, and sellers expect it to be lower. As the seller is not
required to be in possession of the underlying device at the time of the
exchange, futures markets do not rely on inventory (as stock exchanges
do), but instead operate on Open Interest of buyers and sellers.

You can [read more about futures on
Wikipedia](http://en.wikipedia.org/wiki/Futures_contract) 

Bugs/Todos/Errata
-----------------
* Robot AI is weak - it's just for example purposes
* Quantity is not currently supported, all trades sizes are assumed to
  be 1
* The exchange does not currently implement buying power limits or check
  to see if the participant placing the order has sufficient margin.

Copyright
---------
(c) 2012, Scott Burton, all rights reserved
