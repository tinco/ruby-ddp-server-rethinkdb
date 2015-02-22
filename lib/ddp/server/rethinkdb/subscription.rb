module DDP
	module Server
		module RethinkDB
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
