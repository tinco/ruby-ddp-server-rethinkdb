module DDP
	module Server
		module RethinkDB
			# Implementation of the WebSocket DDP::Server
			class WebSocket < DDP::Server::WebSocket
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
		end
	end
end
