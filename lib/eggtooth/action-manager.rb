# Action manager returns the appropriate action for a request based on the
# following parameters:
#
# - `path`: if there's an exact path match (excluding selectors and extension), 
# the action handles it all. The path can be absolute or relative (e.g. 'partial/path');
# - `method` + (`type` || `selectors` || `extension` || `suffix`): `method` constrains
# the relevant actions. From there, any action that matches one or more of the other
# attributes is a contender for handling the request.
#
# When matching other attributes, a basic rank is given to the action based on the
# number of successful matches to each attribute. Implementations are free to choose
# their own ranking system (with the knowledge that too much weighting can prevent
# a better match from being used). See {@see Action.default_rank} for more of an
# explanation on the basic strategy.
#
# Note that if a request's selectors are `a.b.c`, both `a.b` and `b.c` are equivalent
# matches.
class Eggtooth::ActionManager
	include Eggtooth::ServiceManager::Events::EventListener

	METHOD_ALL = '*'

	def initialize()
		@handlers = {METHOD_ALL => []}
	end

	def svc_activate(svc_man, attribs = {})
		@svc_man = svc_man
		cls = Action.to_s
		svc_man.find do |svc, sid, svc_attribs|
			next if svc_attribs[:service]
			if Eggtooth::equal_mixed(cls, svc_attribs[:service])
				add_action(svc)
			end
		end
		svc_man.add_event_listener(self, [Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED, Eggtooth::ServiceManager::TOPIC_SERVICE_STOPPING])
	end

	def svc_deactivate(svc_man, attribs = {})
		svc_man.remove_event_listener(self, [Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED, Eggtooth::ServiceManager::TOPIC_SERVICE_STOPPING])
		@svc_man = nil
	end

	def on_event(event)
		return if !Eggtooth::equal_mixed(Action.to_s, event.payload[:service])
		$stderr.write "event: #{event.inspect}\n"

		action = @svc_man.get_by_sid(event.payload[:sid])
		if event.topic == Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED
			add_action(action)
		else
			remove_action(action)
		end
	end

	def add_action(action)
		if action.paths
			action.paths.each do |path|
				@handlers[path] = [] if !@handlers[path]
				@handlers[path] << action
			end
		else
			action.methods.each do |meth|
				@handlers[meth] = [] if !@handlers[meth]
				@handlers[meth] << action
			end
		end
	end

	def remove_action
		if action.paths
			action.paths.each do |path|
				if @handlers[path]
					@handlers[path].delete(action)
				end
			end
		else
			action.methods.each do |meth|
				if @handlers[meth]
					@handlers[meth].delete(action)
				end
			end
		end
	end

	# Maps a request to an action handler.
	def map(path_info)
		if @handlers[path_info.path] && @handlers[path_info.path].length > 0 
			return @handlers[path_info.path][-1]
		else
			meth = path_info.method
			meth = METHOD_ALL if !@handlers[meth]
			last_action = nil
			last_rank = 0

			@handlers[meth].each do |action|
				rank = action.accept?(path_info)
				next if rank == 0
				if rank >= last_rank
					last_action = action
					last_rank = rank
				end
			end

			return last_action
		end
	end

	module Action
		TYPE_ALL = 'default'

		# Returns the paths this action applies to.
		def paths
		end

		# Returns the methods that this action applies to.
		def methods
		end

		# Applies a score based on the request matching 1 or more of the following:
		# `type`, `selectors`, `extension`, `suffix`. By default, one point is assigned to each
		# attribute.
		#
		# @todo check attributes that are arrays?
		def accept?(path_info)
		end

		#
		def exec(request, response)
		end

		# Helper method to apply default ranking algorithm. The following point system is
		# applied:
		# 
		# - `type`: 1 point
		# - `extension`: 1 point
		# - `suffix`: 1 point
		# - `selectors`: 2 points for exact match; 1 point for partial match
		def self.default_rank(path_info, types, selectors, extension, suffix)
			types = types || []
			selectors = selectors || []
			extension = extension || ''
			suffix = suffix || ''
			points = 0
			if (path_info.resource && Eggtooth.equal_mixed(path_info.resource.type, types)) || types.index('all')
				points += 1
			end
			if Eggtooth.equal_mixed(path_info.extension, extension)
				points += 1
			end
			if Eggtooth.equal_mixed(path_info.suffix, suffix)
				points += 1
			end

			if selectors && path_info.selectors.length > 0
				if Eggtooth::equal_mixed(path_info.selectors, selectors)
					points += 2
				else
					# make sure request selector and action selectors start with '.' so that
					# substring isn't picked up as apart of a larger selector
					prefixed = ".#{path_info.selectors}"
					selectors.each do |sel|
						if prefixed.index(".#{sel}")
							points += 1
							break
						end
					end
				end
			end

			points
		end
	end
end