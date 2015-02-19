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

				def self.rack(api, config, pool_config={})
					super(pool_config.merge(args: [api, config]))
				end

				def initialize(api_class, config)
					collections_module = api_class.const_get :Collections
					@collections = collections_module.instance_methods.map(&:to_s)
					@api = api_class.new(config)
					@subscriptions = {}
				end

				def handle_sub(id, name, params)
					send_nosub(id, error: 'No such collection') unless @collections.include? name
					query = api.send(name, params)
					@subscriptions[id] = Subscription.new(self, id, name, query)
				end

				def subscription_update(id, change)
					subscription_name = @subscriptions[id].name
					old_value = change[:old_value]
					new_value = change[:new_value]

					return send_added(subscription_name, new_value[:id], new_value) if old_value.nil?
					return send_removed(subscription_name, old_value[:id]) if new_value.nil?

					cleared = old_value.keys.reject { |key| new_value.include? key }
					send_changed(subscription.name, old_value[:id], new_value, cleared)
				end

				def handle_unsub(id)
					subscription = @subscriptions.delete(id)
					subscription.stop unless subscription.nil?
					send_nosub(id)
				end

				def handle_method(id, method, params)
					result = @api.send(method, params)
					send_result(id, result)
				rescue => e
					send_error_result(id, e)
				end
			end

			# Helper class that users can extend to implement an API that can be passed
			# as the RPC API parameter to the RethinkDB DDP protocol
			class API
				def initialize(config)
					@connection_pool = ConnectionPool.new(
						size:    config[:connection_pool_size],
						timeout: config[:connection_pool_timeout]
					) do
						::RethinkDB::Connection.new(
							host: config[:host],
							port: config[:port]
						)
					end
					@database_name = config[:database]
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
			end

			# Actor that asynchronously monitors a collection
			class Subscription
				include Celluloid

				attr_reader :name, :stopped

				def initialize(listener, id, name, query)
					@stopped = false
					@name = name

					async.read_loop(listener, query, id)
				end

				def read_loop(listener, query, id)
					listener.api.with_connection do |conn|
						query.changes.run(conn).each do |change|
							listener.update_subscription(id, change)
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
