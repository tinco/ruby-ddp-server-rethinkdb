# Ddp::Server::Rethinkdb

So the idea of this is that you can create a class that exposes an interface to your RethinkDB collections and have it be served over DDP.

Ideally it would look something like this:

```
class MyRethinkDBAPI
	

	def initialize(config)
		@connection_pool = ConnectionPool.new(
			size:    config[:connection_pool_size],
			timeout: config[:connection_pool_timeout]
			) do
				RethinkDB::Connection.new(
					host: config[:host],
					port: config[:port]
				)
		end
		@database_name = config[:database]
	end

	private
	def table(name)
		database.table(name)
	end

	def database
		RethinkDB::RQL.new.db(@database_name)
	end

	def with_connection
		@connection_pool.with do |conn|
			yield conn
		end
	end
end
```


## Installation

Add this line to your application's Gemfile:

    gem 'ddp-server-rethinkdb'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ddp-server-rethinkdb

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it ( https://github.com/[my-github-username]/ddp-server-rethinkdb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
