class Eggtooth_Actions_Post < Test::Unit::TestCase
	
	def setup
		@fwk = Eggtooth::Framework.get_instance('test')
		@resman = @fwk.resource_manager
		@dispatcher = @fwk.dispatcher
		@path_info_post = @resman.path_info('/node', 'POST')
	end

	def teardown
		@resman = nil
		@fwk = nil
	end
	
	def test_mod_log
		modlog = Eggtooth::ActionManager::ServletAction::Post::ModLog.new
		modlog.add(:key, :value)
		modlog.add('./node/path', 'value!!!')
		puts "modlog: #{modlog.inspect}"
	end
	
	def test_request_simple
		env = Rack::MockRequest.env_for('http://localhost:8080/node', {:method => 'POST', :params => {'prop' => 'value', 'prop.time' => Time.new.to_s}})
		request = Eggtooth::Client::Request.new(env, @path_info_post, nil)
		response = Eggtooth::Client::Response.new
		puts request.POST
		@dispatcher.dispatch(request, response)
	end
end