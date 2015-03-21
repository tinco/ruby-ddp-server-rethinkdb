module DDP
	module Server
		# A RethinkDB DDP Server implementation
		module RethinkDB
			# Helper class that users can extend to implement an API that can be passed
			# as the RPC API parameter to the RethinkDB DDP protocol
			module Helpers
				def wrap_query(query)
					lambda do |&on_update|
						connection = new_connection
						results = query.run(connection)
						results.each { |r| on_update.call(nil, r) }
						wrap_changes(query, connection, on_update)
					end
				end

				def wrap_changes(query, conn, on_update)
					query.changes().run(conn).each do |change|
						old_value = change['old_val']
						new_value = change['new_val']
						on_update.call(old_value, new_value)
					end
					conn.close
				end
			end
		end
	end
end
