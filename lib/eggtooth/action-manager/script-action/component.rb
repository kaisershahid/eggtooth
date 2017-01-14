# Model for interacting with a component script.
# @todo pass logger into constructor
class Eggtooth::ActionManager::ScriptAction::Component
	@@log = Logging.logger[self]
	@@log.level = :warn

	# Looks at a component's children and separates them into default and other
	def self.scripts_collector(resource, map = {})
		map[:default] = [] if !map[:default]
		map[:other] = [] if !map[:other]

		resource.children.each do |child|
			next if !child.type.index('file')
			cname = child.name.split('.')[0]
			if cname == resource.name
				map[:default] << child
			end
			
			map[:other] << child
		end
		
		map
	end
	
	@@cache = {}

	# Gets components from cache.
	def self.get_component(resource)
		path = resource.path
		if !@@cache[path]
			@@cache[path] = new(resource)
		end
		
		@@cache[path]
	end
	
	# Clears component cache.
	def self.refresh
		@@cache.clear
	end
	
	def initialize(resource)
		@resource = resource
		@parent_type = @resource.properties[Eggtooth::ResourceManager::PROP_RESOURCE_SUPERTYPE]
		@parent = nil
		if @parent_type
			parentRes = resource.manager.resolve(@parent_type)
			if parentRes
				@parent = self.class.get_component(parentRes)
			end
		end

		# keep list of children matching the name of this script -- these are the candidates for
		# script execution
		@handlers_list = self.class.scripts_collector(resource)
		if @parent
			@handlers_list[:default] += @parent.handlers_list[:default]
			@handlers_list[:other] += @parent.handlers_list[:other]
		end
	end
	
	attr_reader :handlers_list
	protected :handlers_list
	
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
	# If the component has {{script_match_safe}}, only scripts matching the component name
	# will be examined. This prevents invoking a script via selector if it's not meant to be
	# called directly.
	# 
	# @param Array script_ext The script extensions that are supported.
	def script_resource(path_info, script_ext)
		method = path_info.method
		method = nil if method == ''
		path_selectors = ".#{path_info.selectors}."

		last_match_sel = 0
		last_match_res = nil
		last_match_method = false
		last_match_ext = false

		list = @resource.properties['script_match_safe'] ? @handlers_list[:default] : @handlers_list[:other]
		@@log.debug("** checking #{path_info} (method=#{method}, safe=#{@resource.properties['script_match_safe']})")
		# @todo rework scripts_collector to store script names without the component name and resource
		# e.g. if component is named 'comp', and scripts are 'comp.rb', 'comp.selector.rb', and 'method.rb',
		# the list of scripts should be [['', comp], ['selectors', comp.selector.rb], ['method', method.rb]]
		scripts = list.each do |res|
			parts = res.name.split('.')
			parts.shift if parts[0] == @resource.name
			ext = parts.pop
#			puts ">> component: script_resource: checking #{path_info} against #{res.name}"
			@@log.debug(">> examine #{res.path}")
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
				@@log.debug("//method_matched = #{method_matched}")

				# if method matched for first time or no resource selected, set to this resource and continue
				if method_matched
					default_add = !last_match_method
					last_match_method = true
					if !last_match_res || default_add
						last_match_res = res
						next
					end
				end

				# last element matches request extension. if no previous extension
				# found yet, set to this resource and continue
				ext_match = false
				if parts[-1] == path_info.extension
#					puts "> found extension! #{parts[-1]}"
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

				# finally, match selectors. The selectors of this script must be in the request for a match
				script_sel = ".#{parts.join('.')}."
				match_sel = path_selectors.index(script_sel) ? parts.length : 0
				@@log.debug("  script_sel = #{script_sel} ?? #{path_info.selectors}, match=#{match_sel} (last = #{last_match_sel})")
				# if the length of matched selectors is longer than last matched length, use this.
				# only default to this resource if no selectors are present in script and no
				# other script has matched yet. this essentially implies a default script
				if match_sel > last_match_sel
					last_match_sel = match_sel
					last_match_res = res
				elsif !last_match_res && parts.length == 0
					last_match_res = res
				end
			end
			false
		end
		
		last_match_res = @handlers_list[:default][0] if !last_match_res
		last_match_res
	end
	
	# Finds an exact script match in the hierarchy. L2R search will find deepest script in hierarchy.
	def find_script(name)
		found = nil
		@handlers_list[:other].each do |script|
			if script.name == name
				found = script
				break
			end
		end
		found
	end
	
	def parent
		@parent
	end

	# @future
	def edit_fields
	end
end