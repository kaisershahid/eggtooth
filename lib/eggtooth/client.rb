require 'rack/query_parser'

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
			@props[-1].clear
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
		
		def []=(key, val)
			set(key, val)
		end
		
		def each(&block)
			checked = {}
			idx = @props.length-1
			while @props[idx]
				@props[idx].each do |key, val|
					next if !val || checked[key]
					block.call(key, val)
					checked[key] = true
				end
				idx -= 1
			end
		end
		
		def set(key, val, scope = nil)
			scope = @scope if !scope
			return if !scope.is_a?(Fixnum) || !@props[scope]
			@props[scope][key] = val
		end
	end
	
	module HttpUtils
		ESCAPE_CGI = /([^ a-zA-Z0-9_.-]+)/n
		ESCAPE_PHP = /([^ a-zA-Z0-9_.-\[\]]+)/n
		UNESCAPE_CGI = /((?:%[0-9a-fA-F]{2})+)/n

		# Code copied from {@see CGI.escape}, except that user can supply its own
		# regex pattern to escape. By default, {@see ESCAPE_CGI} is used.
		#
		# @param String string The string to escape.
		# @param Regexp pattern The pattern to match. Can also be a {c}String{/}.
		# @return String An escaped string.
		def escape(string, pattern = nil)
			pattern = ESCAPE_CGI if pattern == nil
			string.gsub(pattern) do
				'%' + $1.unpack('H2' * $1.size).join('%').upcase
			end.tr(' ', '+')
		end

		# Code copied from {@see CGI.unescape}. For now, optional pattern not 
		# supported.
		#
		# @param String string The string to unescape.
		# @return String An unescaped string.
		def unescape(string, pattern = nil)
			return '' if !string
			string.tr('+', ' ').gsub(UNESCAPE_CGI) do
				[$1.delete('%')].pack('H*')
			end
		end

		# Fairly simple querystring parser. Unlike Rack's parser, however, multiple
		# keys without brackets are treated as if it's an array (e.g. `key=1&key=2&key=...`
		# becomes `key = [1, 2, ...]`). Keys with brackets are passed to {{expand_params()}}.
		def parse_query(qs, d = nil, &unescaper)
			d = '&' if !d
			unescaper ||= method(:unescape)
			params = {}

			qs.split('&').each do |kv|
				k, v = kv.split('=', 2).map!(&unescaper)
				if k.index('[')
					expand_params(params, k, v)
				elsif (params[k].is_a?(Array))
					params[k] << v
				elsif params[k]
					params[k] = [params[k], v]
				else
					params[k] = v
				end
			end

			params
		end
		
		alias :parse_nested_query :parse_query
		
		# An alternative to Rack's normalize_params that can handle infinite expansion
		# and doesn't recursively call itself. The following forms are handled.
		#
		# pre.
		# key[] -> 'key' is an array
		# key[0] -> 'key' is an array (any unquoted integer)
		# key[subkey] -> 'key' is a hash (non-integer)
		# key['0'], key["1"] -> 'key' is a hash (anything quoted)
		# 
		# Once a particular key is assigned a type, all other parameters must follow that
		# type, otherwise an exception is raised.
		def expand_params(params, k, v)
			# initial condition to pull root key
			lbrack = -1
			rbrack = k.index('[')
			
			# no brackets, so no expansion
			if !rbrack
				if params[k]
					if !params[k].is_a?(Array)
						params[k] = [params[k], v]
					else
						params[k] << v
					end
				else
					params[k] = v
				end
				return params
			end

			ptr = params
			last_ptr = ptr
			last_skey = nil
			
			empty_arr = false

			# loop until no more brackets found or '[]' was encountered
			while !empty_arr && lbrack && rbrack > 0
				skey = k[lbrack+1...rbrack]
				is_num = skey ? skey.match(/^\d*$/) : false

				lbrack = k.index('[', rbrack)
				rbrack = lbrack ? k.index(']', lbrack) : -1
				empty_arr = lbrack ? rbrack - lbrack == 1 : false

				if !is_num
					if skey[0] == '"' || skey[0] == "'"
						quot = skey[0]
						if skey[-1] == quot
							skey = skey[1...-1]
						else
							raise Rack::QueryParser::ParameterTypeError.new("#{k}: misquoted subkey: #{skey}")
						end
					end
				else
					skey = skey.to_i
				end

				# initialize ptr (last_skey) based on current key
				if last_skey
					ptr[last_skey] = skey.is_a?(Numeric) ? [] : {}
					ptr = ptr[last_skey]
					last_skey = nil
				end

				if skey.is_a?(String) && ptr.is_a?(Array)
					raise Rack::QueryParser::ParameterTypeError.new("#{k}: trying to treat an array as a map: #{skey} => #{ptr.inspect}")
				end

				# the current key doesn't exist in ptr, so defer to next round
				if !ptr[skey]
					last_skey = skey
					next
				else
					ptr = ptr[skey]
				end
			end
			
			# param key ends in [], so append value to ptr
			if empty_arr
				if last_skey
					ptr[last_skey] = []
					ptr = ptr[last_skey]
				end
				ptr << v
			else
				if !ptr[last_skey]
					ptr[last_skey] = last_skey.is_a?(Numeric) ? [] : {}
				end
				ptr[last_skey] = v
			end
			
			params
		end

		class BetterParser
			include HttpUtils
			
			def make_params
				Rack::QueryParser::Params.new(10)
			end

			def param_depth_limit
				-1
			end
			
			def normalize_params(params, k, v, depth)
				expand_params(params, k, v)
			end
		end
		
		Rack::Utils.default_query_parser = BetterParser.new
	end

	class Request < Rack::Request
		def initialize(env, path_info, context)
			super(env)
			@path_info = path_info
			@context = context || Context.new
		end

		def path_info
			@path_info
		end
		
		attr_writer :path_info
		protected :path_info=
		
		def context
			@context
		end
		
		# Generates and returns a duplicate request with new path info.
		#
		# @todo support injecting new params?
		def modify(path_info)
			new_req = self.dup
			new_req.path_info = path_info
			return new_req
		end
	end
	
	class Response < Rack::Response
	end
end