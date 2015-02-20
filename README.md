# DDP::Server::RethinkDB

So the idea of this is that you can create a class that exposes an interface to your RethinkDB collections and have it be served over DDP.

Ideally it would look something like this:

```
require 'ddp/server/rethinkdb'

class Messager < DDP::Server::RethinkDB::API
	include Celluloid::Logger

	module Collections
		def messages
			table('messages')
		end
	end

	module RPC
		def send_message(message)
			with_connection do |conn|
				table('messages').insert(from: name, message: message).run(conn)
			end
		end
	end

	def name
		@name ||= "Guest#{rand(10..100)}"
	end
end

config = {
	connection_pool_size: 8,
	connection_pool_timeout: 5,
	host: 'localhost',
	port: 28_015,
	database: 'message'
}

run DDP::Server::RethinkDB::WebSocket.rack(Messager, config)

```

## Installation

Add this line to your application's Gemfile:

    gem 'ddp-server-rethinkdb'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ddp-server-rethinkdb

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it ( https://github.com/[my-github-username]/ddp-server-rethinkdb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
