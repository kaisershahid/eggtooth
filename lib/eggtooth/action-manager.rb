# Action manager returns the appropriate action for a request based on the
# following parameters:
#
# # exact `path` match: only resource path is considered. If multiple matches
# are found, the highest ranking and most recent action is used.
# # partial `path` match: only resourcepath is considered. Any action registered
# with a path ending in '/' and is an ancestor of `path` is used. Only one
# handler can be assigned to a specific branch (e.g. one action for '/branch/' and 
# '/branch/sub/' are valid, but not two for '/branch/'). [*NOTE*]: A valid regular
# expression can also be used here by prefixing the path with {{!}} (e.g. '!/branch/.+/').
# - `method` + (`type` || `selectors` || `extension` || `suffix`): `method` constrains
# the relevant actions. From there, any action that matches one or more of the other
# attributes is a contender for handling the request.
#
# When matching other attributes, a basic rank is given to the action based on the
# number of successful matches to each attribute. Implementations are free to choose
# their own ranking system (with the knowledge that too much weighting can prevent
# a better match from being used). See {Action.default_rank} for more of an
# explanation on the basic strategy.
#
# Note that if a request's selectors are `a.b.c`, both `a.b` and `b.c` are equivalent
# matches, and whichever is a higher rank or registered last is used.
#
# h2. Why?
#
# The algorithm to find an appropriate action assumes that specific or near-specific
# path matches have context-sensitive handling, so the action is responsible for further
# refinement of what action to finally take. For partial matches, given {{!/branch/.+/}}
# and {{/branch/}}, the former takes precedence over the latter since its length implies
# a better match (even if they're functionally equivalent).
#
# When using method, suffix, etc., it's assumed that a general behavior is desired.
class Eggtooth::ActionManager
	include Eggtooth::ServiceManager::Events::EventListener

	METHOD_ALL = '*'

	def initialize()
		@handlers = {METHOD_ALL => [], :exact => {}, :partial => {}}
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
				ptr = @handlers[:exact]
				if path.end_with?('/')
					ptr = @handlers[:partial]
					if !path.start_with?('!')
						path = Regexp.escape(path)
					else
						path = path[1..-1]
					end
				end
				ptr[path] = [] if !ptr[path]
				ptr[path] << action
			end
		end
		
		if action.methods
			action.methods.each do |meth|
				@handlers[meth] = [] if !@handlers[meth]
				@handlers[meth] << action
			end
		end
	end

	def remove_action
		if action.paths
			action.paths.each do |path|
				ptr = @handlers[:exact]
				if path.end_with?('/')
					ptr = @handlers[:partial]
					if !path.start_with?('!')
						path = Regexp.escape(path)
					else
						path = path[1..-1]
					end
				end
				if ptr[path]
					ptr[path].delete(action)
				end
			end
		end
		
		if action.methods
			action.methods.each do |meth|
				if @handlers[meth]
					@handlers[meth].delete(action)
				end
			end
		end
	end

	# Maps a request to an action handler. If 
	def map(path_info)
		path = path_info.path
		action = nil

		# priority 1: exact patch match
		if @handlers[:exact][path] && @handlers[:exact][path].length > 0 
			action = map_best(path_info, @handlers[:exact][path])
			return action if action
		end
		
		# priority 2: longest branch partial match
		last_branch = nil
		@handlers[:partial].each do |branch, branch_act|
			if path.matches(branch)
				if !last_branch || last_branch.length < branch.length
					last_branch = branch
					action = branch_act
				end
			end
			return action if action	
		end
		
		# priority 3: 
		meth = path_info.method
		meth = METHOD_ALL if !@handlers[meth]
		last_action = nil
		last_rank = 0

		action = map_best(path_info, @handlers[meth])

		action
	end
	
	def map_best(path_info, candidates)
		last_action = nil
		last_rank = 0
		candidates.each do |action|
			rank = action.accept?(path_info)
			next if rank == 0
			if rank >= last_rank
				last_action = action
				last_rank = rank
			end
		end
		last_action
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