# Model for interacting with a component script.
class Eggtooth::ActionManager::ScriptAction::Component
	def initialize(resource)
		@resource = resource
		@parent_type = @resource.properties[Eggtooth::ResourceManager::PROP_RESOURCE_SUPERTYPE]

		# keep list of children matching the name of this script -- these are the candidates for
		# script execution
		# @todo inject matching ancestor scripts here too
		name = "#{@resource.name}."
		@handlers_list = []
		@resource.children.each do |child|
			if child.name.start_with?(name)
				@handlers_list << child
			end
			false
		end
		
	end
	
	# Finds the best matching script resource for a given request's path info. Order
	# of precedence for best script match:
	#
	# # Matches method
	# # Matches extension
	# # Has longest matching selector
	#
	# This means that if there's a POST request, and there's a choice between a POST-specific
	# script or an exact match to selectors and extension, the POST-specific script wins.
	# Likewise, an extension-specific script wins over longest matching selector.
	# 
	# @param Array script_ext The script extensions that are supported.
	def script_resource(path_info, script_ext)
		method = path_info.method
		method = nil if method == ''

		last_match_sel = 0
		last_match_res = nil
		last_match_method = false
		last_match_ext = false

		scripts = @handlers_list.each do |res|
			parts = res.name.split('.')
			name = parts.shift
			ext = parts.pop

			if Eggtooth::equal_mixed(ext, script_ext)
				# check if there's a script matching the method given, since these take higher precedence
				method_matched = false
				if method
					# since we already found a method-specific script, that automatically takes precedence
					if last_match_method && parts[0] != method
						false
						next
					elsif parts[0] == method
						method_matched = true
						parts.shift
					end
				end

				# if method matched for first time or no resource selected, set to this resource and continue
				if method_matched
					default_add = !last_match_method
					last_match_method = true
					if !last_match_res || default_add
						last_match_res = res
						next
					end
				end

				# last element matches request extension. take it out; if no previous extension
				# found yet, set to this resource and continue
				ext_match = false
				if parts[-1] == path_info.extension
					parts.pop
					default_add = !last_match_ext
					last_match_ext = true
					if default_add
						last_match_res = res
						next
					end
					ext_match = true
				end
				
				if last_match_ext && !ext_match
					next
				end

				# finally, match selectors
				match_sel = ''
				req_sel = ".#{path_info.selectors}."
				while parts.length > 0
					sel = ".#{parts.join('.')}."
					if sel == req_sel || req_sel.index(sel)
						match_sel = sel
						break
					end
					parts.pop
				end
				
				# if the length of matched selectors is longer than last matched length, use this.
				# note that we're only going by number of selectors matched,
				if parts.length > last_match_sel
					last_match_sel = parts.length
					last_match_res = res
				elsif !last_match_res
					last_match_res = res
				end
			end
			false
		end
		
		# @todo look at parent matches
		last_match_res
	end
	
	def parent
		# @todo look at egg:resourceSuperType
	end

	# @future
	def edit_fields
	end
end