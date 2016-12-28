# Classes and interfaces for client-related interactions. Rack's request/response
# objects will be used as the basis, with a few extensions.
module Eggtooth::Client
	# Holds key-value pairs for a request that the application can modify. Keys
	# can have various scopes, so that subrequests can have their own set of 
	# common values without erasing a higher level.
	class Context
		SCOPE_TOP = 0
		SCOPE_REQUEST = 1
		SCOPE_PAGE = 2
		SCOPE_INCLUDE = 3
		
		def initialize(props = nil)
			@props = [props.is_a?(Hash) ? props : {}]
			@scope = SCOPE_TOP
		end
		
		attr :scope

		# Push a new client state
		def push
			@scope += 1
			@props << {}
		end
		
		def pop
			@scope -= 1
			@props.pop
		end
		
		def [](key)
			sc = @scope
			ptr = @props[sc]
			while ptr
				return ptr[key] if ptr.has_key?(key)
				sc -= 1
				ptr = ptr[sc]
			end
			nil
		end
		
		def set(key, val, scope)
			return if !scope.is_a?(Fixnum) || !@props[scope]
			@props[scope][key] = val
		end
	end

	class Request < Rack::Request
		def initialize(env, path_info, context)
			super(env)
			@path_info = path_info
			@context = context
		end

		def path_info
			@path_info
		end

		def context
			@context
		end
	end
	
	class Response < Rack::Response
	end
end

#require_relative './client/http.rb'