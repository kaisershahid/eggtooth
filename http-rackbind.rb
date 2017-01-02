require_relative './lib/eggtooth.rb'
require_relative './lib/eggtooth/client/http.rb'

opts = {}
ARGV.each do |arg|
	key, val = arg.split('=', 2)
	opts[key.to_sym] = val
end

framework = Eggtooth::Framework.get_instance('http.rack', opts)
framework.startup

app = Eggtooth::Client::Http::RackBind.new(framework)

Rack::Handler::WEBrick.run app