require 'ddp/server/rethinkdb/version'
require ''

module DDP
	module Server
		# A RethinkDB DDP Server
		module RethinkDB
			class WebSocket < DDP::Server::WebSocket
				attr_reader :api

				def self.rack(api, config, pool_config)
					super(pool_config.merge(args: [api, config]))
				end

				def initialize(api_class, config)
					collections_module = api_class.const_get :Collections
					@collections = @collections_module.instance_methods.map(&:to_s)
					@api = api_class.new(config)
					@subscriptions = {}
				end

				def handle_sub(id, name, params)
					if @collections.include? name
						query = api.send(name)
						@subscriptions[id] = Subscription.new(self, id, name, query)
					end
				end

				def subscription_update(id, change)
					subscription = @subscriptions[id]

					old_value = change[:old_value]
					new_value = change[:new_value]

					if old_value.nil?
						send_added(subscription.name, change[:new_value][:id], change[:new_value])
					elsif new_value.nil?
						send_removed(subscription.name, change[:old_value][:id])
					else
						cleared = old_value.keys.reject {|key| new_value.include? key }
						send_changed(subscription.name, change[:old_value][:id], change[:new_value], cleared)
					end
				end

				def handle_unsub(id)
					subscription = @subscriptions.delete(id)
					subscription.stop unless subscription.nil?
					send_nosub(id)
				end

				def handle_method(id, method, params)
					async do
						result = @api.send(method, params)
						send_result(id, result)
					rescue => e
						send_error_result(id, e)
					end
				end
			end

			class API
				def initialize(config)
					@connection_pool = ConnectionPool.new(
						size:    config['connection_pool_size'],
						timeout: config['connection_pool_timeout']
					) do
						RethinkDB::Connection.new(
							host: config['host'],
							port: config['port']
						)
					end
					@database_name = config['database']
				end

				def database
					RethinkDB::RQL.new.db(@database_name)
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

			class Subscription
				include Celluloid

				attr_reader :name

				def initialize(listener, id, name, query)
					@stopped = false
					@name = name

					async.read_loop(listener, query, id)
				end

				def read_loop(listener, query, id)
					listener.api.with_connection do |conn|
						query.changes().run(conn).each do |change|
							listener.update_subscription(id, change)
							break if stopped?
						end
					end
				end

				def stop
					@stopped = true
				end

				def stopped?
					@stop
				end
			end
		end
	end
end
