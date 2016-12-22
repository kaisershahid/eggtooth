# 
module Eggtooth::ServiceManager::Events
	class Event
		def initialize(topic, payload)
			@topic = topic
			@payload = payload
		end
		attr_reader :topic, :payload
	end

	module EventListener
		def on_event(event)
		end
	end
end