require 'ddp/server/rethinkdb/version'

module DDP
	module Server
		# A RethinkDB DDP Server
		module RethinkDB
			class WebSocket < DDP::Server::WebSocket
				def self.rack(api, config, pool_config)
					super(pool_config.merge(args: [api, config]))
				end

				def initialize(api_class, config)
					@api = api_class.new(config)
				end

				def handle_sub(id, name, params)
					raise 'Todo'
				end

				def handle_unsub(id)
					raise 'Todo'
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
		end
	end
end
