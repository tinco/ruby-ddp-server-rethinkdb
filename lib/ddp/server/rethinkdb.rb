require 'ddp/server'
require 'ddp/server/rethinkdb/version'
require 'rethinkdb'
require 'connection_pool'

module DDP
	module Server
		# A RethinkDB DDP Server
		module RethinkDB
			# Implementation of the WebSocket DDP::Server
			class WebSocket < DDP::Server::WebSocket
				include Celluloid::Logger

				attr_reader :api

				def self.rack(api, config, pool_config = {})
					super(pool_config.merge(args: [api, config]))
				end

				def initialize(api_class, config)
					@api = api_class.new(config)
					@subscriptions = {}
				end

				def handle_sub(id, name, params)
					params ||= []
					query = @api.collection_query(name, *params)
					@subscriptions[id] = Subscription.new(self, id, name, query)
				rescue => e
					send_error_result(id, e)
				end

				def subscription_update(id, change)
					subscription_name = @subscriptions[id].name
					old_value = change['old_val']
					new_value = change['new_val']

					return send_added(subscription_name, new_value['id'], new_value) if old_value.nil?
					return send_removed(subscription_name, old_value['id']) if new_value.nil?

					cleared = old_value.keys.reject { |key| new_value.include? key }
					send_changed(subscription.name, old_value['id'], new_value, cleared)
				end

				def handle_unsub(id)
					subscription = @subscriptions.delete(id)
					subscription.stop unless subscription.nil?
					send_nosub(id)
				end

				def handle_method(id, method, params)
					params ||= []
					result = @api.invoke_rpc(method, *params)
					send_result(id, result)
				rescue => e
					send_error_result(id, e)
				end
			end

			# Helper class that users can extend to implement an API that can be passed
			# as the RPC API parameter to the RethinkDB DDP protocol
			class API
				def initialize(config)
					setup_connection_pool(config)

					@database_name = config[:database]

					setup_rpc
					setup_collections
				end

				def invoke_rpc(method, *params)
					raise 'No such method' unless @rpc_methods.include? method
					send(method, *params)
				end

				def collection_query(name, *params)
					raise 'No such collection' unless @collections.include? name
					send(name, *params)
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

				private

				def setup_connection_pool(config)
					@connection_pool = ConnectionPool.new(
						size:    config[:connection_pool_size],
						timeout: config[:connection_pool_timeout]
					) do
						::RethinkDB::Connection.new(
							host: config[:host],
							port: config[:port]
						)
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
			end

			# Actor that asynchronously monitors a collection
			class Subscription
				include Celluloid

				attr_reader :name, :stopped
				alias_method :stopped?, :stopped

				def initialize(listener, id, name, query)
					@stopped = false
					@name = name
					async.read_loop(listener, query, id)
				end

				def read_loop(listener, query, id)
					listener.api.with_connection do |conn|
						query.changes.run(conn).each do |change|
							listener.subscription_update(id, change)
							break if stopped?
						end
					end
				end

				def stop
					@stopped = true
				end
			end
		end
	end
end
