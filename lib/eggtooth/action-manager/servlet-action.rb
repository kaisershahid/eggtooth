# A base module for scriptless actions that map to a path or handle resources by 
# type, selector, extension, and method. There are some pre-filled methods along
# with hooks that an implementing class can override.
#
# {{svc_activate()}} initializes the following properties: {{@paths}} (`nil` if 0-length),
# {{@types}}, {{@methods}}, {{@extensions}}, {{@selectors}}, and {{@suffixes}}.
# 
# {{accept?()}} calls {{Action.default_rank}}.
# 
# Borrowing the servlet terminology from Java.
module Eggtooth
	class ActionManager
		module ServletAction
			include Action
			
			PROP_PATHS = "action.path"
			PROP_TYPES = "action.type"
			PROP_METHODS = "action.method"
			PROP_EXTENSIONS = "action.extension"
			PROP_SELECTORS = "action.selector"
			PROP_SUFFIX = "action.suffix"

			def svc_activate(svc_man, attribs)
				@svc_man = svc_man
				@attribs = attribs
				
				@paths = Eggtooth.get_value(attribs[PROP_PATHS], Array)
				@paths = nil if @paths.length == 0
				@types = Eggtooth.get_value(attribs[PROP_TYPES], Array)
				@methods = Eggtooth.get_value(attribs[PROP_METHODS], Array)
				@extensions = Eggtooth.get_value(attribs[PROP_EXTENSIONS], Array)
				@selectors = Eggtooth.get_value(attribs[PROP_SELECTORS], Array)
				@suffixes = Eggtooth.get_value(attribs[PROP_SUFFIX], Array)

				_activate
			end
			
			def svc_deactivate(svc_man, attribs)
				_deactivate
				@attribs = nil
				@svc_man = nil
			end
			
			# Called after svc_activate completes boilerplate functions.
			def _activate
			end
			
			# Called before svc_deactivate does boilerplate functions.
			def _deactivate
			end
			
			def paths
				@paths
			end

			def methods
				@methods
			end

			def accept?(path_info)
				rank = Action.default_rank(path_info, @types, @selectors, @extensions, @suffixes)
				if @methods.find_index(path_info.method)
					rank += 1
				end
			end
		end
	end
end

require_relative './servlet-action/post.rb'