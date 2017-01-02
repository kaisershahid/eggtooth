module Eggtooth::Client::Http
	class RackBind
		def initialize(framework)
			@framework = framework
			#@dispatcher = @framework.get_by_sid('dispatcher')
		end
		
		def call(env)
			path_info = @framework.resource_manager.path_info(env['REQUEST_PATH'], env['REQUEST_METHOD'])
			ctx = Eggtooth::Client::Context.new
			req = Eggtooth::Client::Request.new(env, path_info, ctx)
			res = Eggtooth::Client::Response.new
			
			@framework.dispatcher.dispatch(req, res)
			#res.write env.inspect
			res
		end
	end
end