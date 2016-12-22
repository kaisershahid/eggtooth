# The service manager is a repository for objects that provide some kind of
# functionality. Its main function is to allow consumers to query services 
# based on various attributes, and also send/receive notifications for events
# happening within the framework. In the future, lifecycle management and
# dependency checks will be added.
#
# One specific use case is for the resolver manager: instances of handlers
# registered to the service manager will result in the resolver manager 
# getting notified, allowing it to add the handler to its list.
class Eggtooth::ServiceManager
	KEY_SID = :sid
	KEY_SERVICE = :service
	KEY_RANKING = :ranking

	TOPIC_SERVICE_REGISTERED = 'eggtooth/servicemanager/service/registered'
	TOPIC_SERVICE_UNREGISTERED = 'eggtooth/servicemanager/service/unregistered'
	TOPIC_SERVICE_STOPPING = 'eggtooth/servicemanager/service/stopping'

	def initialize
		@services = {}
		@event_listeners = {}
	end
	
	def add(svc_inst, attribs = {})
		atts = (attribs||{}).clone
		atts[:sid] = svc_inst.class.to_s + '.' + Time.new.to_i.to_s if !atts[:sid]
		
		# infer exposed interfaces. ignore root ancestors
		if !atts[:service]
			atts[:service] = []
			svc_inst.class.ancestors.each do |cls|
				svctype = cls.to_s
				next if !svctype.index('::') || cls.is_a?(Class)
				atts[:service] << svctype
			end
		end
		
		@services[atts[:sid]] = [] if !@services[atts[:sid]]
		@services[atts[:sid]] << {:svc => svc_inst, :attribs => atts}
		
		if svc_inst.respond_to?(:svc_activate)
			svc_inst.svc_activate(self, atts)
		end
		
		generate_event(TOPIC_SERVICE_REGISTERED, atts.clone)
	end
	
	def remove(svc_inst)
		# @todo find service or return if not found
		atts = {}
		generate_event(TOPIC_SERVICE_STOPPING, atts.clone)

		if svc_inst.respond_to?(:svc_deactivate)
			svc_inst.svc_deactivate(self, atts)
		end

		generate_event(TOPIC_SERVICE_UNREGISTERED, atts.clone)
	end
	
	def get_by_service(service_type)
		service_type = service_type.to_s if service_type.is_a?(Class)
		return query({:service => service_type})[0]
	end
	
	def get_by_sid(sid)
		sid = sid.to_s if sid.is_a?(Class)
		return query({:sid => sid})[0]
	end
	
	# Finds one or more services matching the values in the query against service attributes.
	# @todo support and/or, not just and
	def query(query)
		list = []
		@services.each do |sid, entries|
			entries.each do |entry|
				hit = 0
				miss = 0
				query.each do |key,val|
					if entry[:attribs][key].is_a?(Array)
						if entry[:attribs][key].find_index(val) != nil
							hit += 1
						else
							miss += 1
						end
					else
						if entry[:attribs][key] == val
							hit += 1
						else
							miss += 1
						end
					end
				end

				if hit > 0 && miss == 0
					list << entry[:svc]
				end
			end
		end
		
		return list
	end
	
	# Iterates through all services, yielding to a block to match and collect.
	# Block should accept these parameters: `service_instance, service_id, attributes`.
	def find(&block)
		@services.each do |sid, entries|
			entries.each do |entry|
				yield(entry[:svc], sid, entry[:attribs].clone)
			end
		end
	end

	# Adds an event listener for framework events.
	# @param EventListener listener
	# @param String|Array topics One or more event topics to subscribe to.
	def add_event_listener(listener, topics)
		if listener.is_a?(Eggtooth::ServiceManager::Events::EventListener)
			topics = [topics] if topics.is_a?(String)
			topics.each do |topic|
				@event_listeners[topic] = [] if !@event_listeners[topic]
				@event_listeners[topic] << listener
			end
		end
	end

	# Removes a listener from one or more topics.
	# @param EventListener listener
	# @param String|Array topics One or more event topics to unsubscribe from.
	def remove_event_listener(listener, topics)
		topics = [topics] if topics.is_a?(String)
		topics.each do |topic|
			next if !@event_listeners[topic]
			@event_listeners[topic].delete(listener)
		end
	end

	# Generates a framework event.
	# @param String topic
	# @param Object payload
	def generate_event(topic, payload)
		if @event_listeners[topic]
			evt = Eggtooth::ServiceManager::Events::Event.new(topic, payload)
			@event_listeners[topic].each do |listener|
				listener.on_event(evt)
			end
		end
	end
end

require_relative './service-manager/events.rb'