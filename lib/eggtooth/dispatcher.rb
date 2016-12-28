class Eggtooth::Dispatcher
	include Eggtooth::ServiceManager::Events::EventListener

	def initialize
		@filters = {}
	end
	
	def svc_activate(svc_man, attribs = {})
		@svc_man = svc_man
		svc_man.add_event_listener(self, [Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED, Eggtooth::ServiceManager::TOPIC_SERVICE_STOPPING])
	end

	def svc_deactivate(svc_man, attribs = {})
		svc_man.remove_event_listener(self, [Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED, Eggtooth::ServiceManager::TOPIC_SERVICE_STOPPING])
		@svc_man = nil
	end

	# Adds or remove filters as they come into the system. For adding a filter,
	# it must expose {{Eggtooth::Dispatcher::Filter}} and have a scope defined.
	def on_event(event)
		return if !event.payload[:service] || !event.payload[:service].find_index(Filter.to_s)
		return if !event.payload[:filter_scope]

		filter = @svc_man.get_by_sid(event.payload[:sid])
		scope = event.payload[:filter_scope]
		rank = event.payload[:ranking] || 0
		if event.topic == Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED
			add_filter(filter, scope, rank)
		else
			remove_filter(filter, scope)
		end
	end

	def add_filter(filter, scope, rank)
		@filters[scope] = {} if !@filters[scope]
		@filters[scope][rank] = [] if !@filters[scope][rank]
		@filters[scope][rank] << filter
	end

	def remove_filter(filter, scope)
		return if !@filters[scope]
		@filters[scope].each do |rank, chain|
			if chain.find_index(filter)
				chain.delete(filter)
			end
		end
	end

	def exec_filters(scope, request, response)
		return if !@filters[scope]
		@filters[scope].keys.sort.each do |rank|
			@filters[scope][rank].each do |filter|
				val = filter.filter(request, response, scope)
				if val == :stop
					break
				end
			end
		end
	end

	def dispatch(request, response)
		begin
			# prepare request
			exec_filters(Filter::SCOPE_REQUEST, request, response)

			# prepare for execution
			exec_filters(Filter::SCOPE_PAGE, request, response)
			am = @svc_man.get_by_sid('action.manager')
			handler = am.map(request.path_info)

			if !handler
				# @todo ??
			else
				handler.exec(request, response)
			end

			# apply any filters to outut
			exec_filters(Filter::SCOPE_RESPONSE, request, response)
		rescue HaltProcessingException => hpe

		rescue Exception => ex
			# @todo unhandled error
			response.write "uh oh... #{ex}\n#{ex.backtrace.join("\n\t")}"
		end
	end

	# 
	def subrequest(path, request, response)
		
	end

	# Filters allow the manipulation of requests and responses. Used for everything
	# from authentication to caching to debugging. Filters are grouped into various
	# scopes and called during that phase of execution. An optional rank is attached
	# to them.
	module Filter
		# Top-level filters for preparing request.
		SCOPE_REQUEST = "request"
		# Filters to apply right before executing action handler.
		SCOPE_PAGE = "page"
		# Filters to apply before a sub-request is made.
		SCOPE_INCLUDE = "include"
		# Filters to apply for response.
		SCOPE_RESPONSE = "response"

		# @return Symbol {{:stop}} aborts calling other filters. Otherwise, continue
		# processing next filter.		
		def filter(request, response, scope)
		end
	end

	# Use this exception to abort normal processing chain.
	class HaltProcessingException < Exception
		def initialize(message)
			super(message)
			@props = {}
		end
		
		attr_reader :props
	end
end