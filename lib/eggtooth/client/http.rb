module Eggtooth::Client::Http
	class RackBind
		def initialize(framework)
			@framework = framework
			#@dispatcher = @framework.get_by_sid('dispatcher')
		end
		
		def call(env)
			env['rack.logger'] = @framework.logger('stdout')
			env['rack.errors'] = @framework.logger('stderr')

			path_info = @framework.resource_manager.path_info(env['REQUEST_PATH'], env['REQUEST_METHOD'])
			ctx = Eggtooth::Client::Context.new
			req = Eggtooth::Client::Request.new(env, path_info, ctx)
			res = Eggtooth::Client::Response.new
			
			@framework.dispatcher.dispatch(req, res)
			res
		end
	end
end