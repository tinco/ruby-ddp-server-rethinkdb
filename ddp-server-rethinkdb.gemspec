# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ddp/server/rethinkdb/version'

Gem::Specification.new do |spec|
	spec.name          = 'ddp-server-rethinkdb'
	spec.version       = DDP::Server::RethinkDB::VERSION
	spec.authors       = ['Tinco Andringa']
	spec.email         = ['mail@tinco.nl']
	spec.summary       = 'Write a DDP RethinkDB service using Ruby.'
	spec.description   = 'Write a DDP RethinkDB service using Ruby.'
	spec.homepage      = 'https://github.com/d-snp/ruby-ddp-server-rethinkdb'
	spec.license       = 'MIT'

	spec.files         = `git ls-files -z`.split("\x0")
	spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
	spec.test_files    = spec.files.grep(/^(test|spec|features)\//)
	spec.require_paths = ['lib']

	spec.add_development_dependency 'bundler', '~> 1.6'
	spec.add_development_dependency 'rake'

	spec.add_dependency 'ddp-server', '>= 0.1.0'
	spec.add_dependency 'rethinkdb'
	spec.add_dependency 'connection_pool'
end
