# Standard POST servlet handling modifications to content. Any other POST actions should
# be extremely cautious and register actions with more specificity (knowing that the 
# default functionality will be gone).
#
# A POST done to a path will be parsed out as follows:
#
# - any parameter with a prefix of {{./name}} refers to the child resource
# {{name}} and must contain a property (e.g. {{./name/property}}). Descendants
# deeper down can be referred to with {{./name/level1/.../property}}.
# 	- if one or more paths don't already exist, an attempt is made to create them
# - other parameters are taken as the properties of the resource being pointed to
# - special parameters, in the form {{property@Hint}} are reserved for special actions
# (e.g. {{property@Type=Integer}} will force {{property}} into an integer). Further
# discussion about this is discussed later.
#
# @todo define _activate to listen for Operation registration
#
# h2. Hints
#
# h3. {{Copy}}: `property@Copy=/resource/property`
#
# The resource property pointed to will be copied into {{property}}.
#
# h3. {{Delete}}: `property@Delete`
#
# The resource or property pointed to will be deleted.
#
# h3. {{Move}}: 
class Eggtooth::ActionManager::ServletAction::Post
	include Eggtooth::ActionManager::ServletAction
	
	TYPE_KEY = Eggtooth::ResourceManager::PROP_TYPE

	def _activate
		@log = Logging.logger[self]
		@log.info("_activate: types=#{@types.inspect}, methods=#{@methods.inspect}")
	end

	protected :_activate

	def exec(request, response)
		mods = ModLog.new
		hints = []
		specials = {}

		request.POST.each do |k,v|
			@log.debug "#{k} = #{v}"
			if k.index('@')
				hints << k
			elsif k[0] == ':'
				specials[k] = v
			else
				mods.add(k, v)
			end
		end

		# @todo process specials other than :operation

		hints.each do |hint|
			mods.apply_hint(hint, request)
		end
		
		op = nil
		# @todo :operation hook: modify/validate

		resource = request.path_info.resource
		begin
			mods.commit(resource)
			# @todo :operation hook: post-validate?
		rescue => ex
			# @todo 500 response?
			@log.error("error processing POST: #{resource} #{ex}#{ex.backtrace.join("\n\t")}")
		end
	end

	class HintHandler
	end

	# Stores pending changes into a map. When ready, the log is applied to a resource.
	class ModLog
		def initialize
			@log = Logging.logger[self]
			@props = {}
			@subresources = {}
		end

		# Generates a subresource tree.
		def get_subresource(partial_path)
			partial_path = partial_path.split('/') if partial_path.is_a?(String)
			ptr = self
			while partial_path.length > 0
				name = partial_path.shift
				if !ptr.subresources[name]
					ptr.subresources[name] = self.class.new
				end
				ptr = ptr.subresources[name]
			end
			ptr
		end
		
		protected :get_subresource
		
		def add(property, value)
			property = property.to_s if !property.is_a?(String)
			if property[0..1] == './'
				parts = property[2..-1].split('/')
				key = parts.pop
				if parts.length > 0
					subres = get_subresource(parts)
					subres.add(key, value)
				else
					@props[key] = value
				end
			else
				@props[property] = value
			end
		end
		
		def delete_self
			@del = true
		end
		
		def subresources
			@subresources
		end
		
		def apply_hint(hint, request)
			hint_val = request.params[hint]
			prop, hint = hint.split('@')

			# resolve deepest subresource. if ptr_mod is nil, that means ...?
			ptr_mod = self
			res = request.path_info.resource
			last_res = nil
			if prop[0..1] == './'
				parts = prop[2..-1].split('/')
				prop = parts.pop
				if parts.length > 0
					ptr_mod = get_subresource(parts)
					# @todo what to do if resource is nil?
					parts.each do |part|
						last_res = res
						res = res.child(part)
						break if !res
					end
				end
			end
			
			if hint == 'Copy'
				parts = hint_val.split('/')
				key = parts.pop
				if parts.length > 0
					res = res.manager.resolve(parts.join('/'))
				end
				if res
					@props[prop] = res.properties[key] if res.properties[key]
				end
			elsif hint == 'Delete'
				if prop != ''
					@props[prop] = :del
				end
			elsif hint == 'DefaultValue'
				res.properties[prop] = hint_val
			end
			# @todo more
		end

		def commit(resource)
			del = []
			@log.info("commit: #{resource.path} => #{@props.inspect}")
			@props.each do |key, val|
				@log.info("checking prop: #{key} => #{val}")
				# @todo any other special cases to consider
				if val == :del
					del << key
				else
					@log.info("before")
					resource.properties[key] = val
					@log.info("after")
				end
			end

			@log.info("editor: #{resource.editor}")
			resource.editor.modify(resource)

			@subresources.each do |name, log|
				child = resource.child(name)
				if !child && log.length > 0
					# @todo more checks to this
					synth = Eggtooth::ResourceManager::NonExistingResource.new("#{resource.path}/#{name}", nil, {TYPE_KEY => log.props[TYPE_KEY]})
					child = resource.handler.add(synth)
				end

				log.commit(child)
			end
		end
		
		def length
			@props.length
		end
		
		def inspect
			"((props=#{@props.inspect} [#{@subresources.inspect}]))"
		end
	end
	
	# Post operations that need extra processing can by registering an {{Operation}}
	# service. If the parameter `:operation` is given, the value is matched available
	# operations and if found, the operation is called.
	module Operation
	end
end