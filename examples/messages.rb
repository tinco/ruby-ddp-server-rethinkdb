require 'ddp/server/rethinkdb'

class Messager < DDP::Server::RethinkDB::API
	include Celluloid::Logger

	module Collections
		def messages
			table('messages')
		end
	end

	def name
		@name ||= "Guest#{rand(10..100)}"
	end

	def send_message(message)
		with_connection do |conn|
			table('messages').insert(from: name, message: message).run(conn)
		end
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
