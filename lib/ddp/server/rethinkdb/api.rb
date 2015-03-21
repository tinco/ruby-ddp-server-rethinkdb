require 'ddp/server/api'

module DDP
	module Server
		# A RethinkDB DDP Server implementation
		module RethinkDB
			# Helper class that users can extend to implement an API that can be passed
			# as the RPC API parameter to the RethinkDB DDP protocol
			class API < DDP::Server::API
				include Helpers

				attr_accessor :database_name

				def initialize(config)
					super()

					@config = config
					@database_name = config[:database]

					setup_connection_pool
				end

				def database
					::RethinkDB::RQL.new.db(@database_name)
				end

				def table(name)
					database.table(name)
				end

				def with_connection
					@connection_pool.with do |conn|
						yield conn
					end
				end

				def new_connection
					::RethinkDB::Connection.new(
						host: @config[:host],
						port: @config[:port]
					)
				end

				private

				def setup_connection_pool
					@connection_pool = ConnectionPool.new(
						size:    @config[:connection_pool_size],
						timeout: @config[:connection_pool_timeout]
					) do
						new_connection
					end
				end
			end
		end
	end
end
