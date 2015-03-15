module DDP
	module Server
		# A RethinkDB DDP Server implementation
		module RethinkDB
			# Helper class that users can extend to implement an API that can be passed
			# as the RPC API parameter to the RethinkDB DDP protocol
			class API
				attr_accessor :database_name

				def initialize(config)
					@config = config
					@database_name = config[:database]

					setup_connection_pool
					setup_rpc
					setup_collections
				end

				def invoke_rpc(method, *params)
					raise 'No such method' unless @rpc_methods.include? method
					send(method, *params)
				end

				def collection_query(name, *params)
					raise 'No such collection' unless @collections.include? name
					wrap_query send(name, *params)
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

				def setup_rpc
					rpc_module = self.class.const_get :RPC
					@rpc_methods = rpc_module.instance_methods.map(&:to_s)
					singleton_class.include rpc_module
				end

				def setup_collections
					collections_module = self.class.const_get :Collections
					@collections = collections_module.instance_methods.map(&:to_s)
					singleton_class.include collections_module
				end

				def wrap_query(query)
					lambda do |&on_update|
						connection = new_connection
						results = query.run(connection)
						results.each { |r| on_update.({}, r['id'], r) }
						wrap_changes(query, conn, on_update)
					end	
				end

				def wrap_changes(query, conn, on_update)
					query.run(conn).each do |change|
						old_value = change['old_value']
						new_value = change['new_value']
						on_update.(old_value, new_value)
					end
				end
			end
		end
	end
end
