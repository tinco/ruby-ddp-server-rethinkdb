require 'ddp/server/rethinkdb'
require 'ddp/server/rethinkdb/api'

# A simple messaging API
class Messager < DDP::Server::RethinkDB::API
	# Define a module named Collections that exposes subscribable rethinkdb queries
	module Collections
		def messages
			table('messages')
		end
	end

	# Define a module named RPC that exposes RPC methods
	module RPC
		def send_message(message)
			with_connection do |conn|
				table('messages').insert(from: name, message: message).run(conn)
			end
		end
	end

	# Other methods are not available to RPC nor are they subscribable
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

run DDP::Server::WebSocket.rack(Messager, config)
