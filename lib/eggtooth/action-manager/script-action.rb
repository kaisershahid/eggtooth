# Uses the resource manager to locate and execute the corresponding resource type script.
# The matching resource found to handle requests is referred to as a component (or component
# script).
#
# {{ScriptAction}} keeps track of {{Compiler}}s that translate a {{Component}} into an
# executable piece of code.
#
# Note that if a resource doesn't have its `egg:resourceType` or `egg:resourceSuperType` 
# property, its type is used and mapped to the directory {{/libs/components/default/$type}}.
class Eggtooth::ActionManager::ScriptAction
	include Eggtooth::ActionManager::Action
	include Eggtooth::ServiceManager::Events::EventListener

	EAM = Eggtooth::ActionManager

	PATH_TYPE_ROOT = "/libs/sys/components/default"
	PROP_RESOURCE_TYPE = Eggtooth::ResourceManager::PROP_RESOURCE_TYPE
	PROP_RESOURCE_SUPERTYPE = Eggtooth::ResourceManager::PROP_RESOURCE_SUPERTYPE

	def initialize(framework, opts)
		# @todo get supported script extensions
		# @todo get script handlers
		@opts = opts.is_a?(Hash) ? opts : {}
		@resman = framework.resource_manager
		@svcman = framework.service_manager
		@svcman.add_event_listener(self, [Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED, Eggtooth::ServiceManager::TOPIC_SERVICE_STOPPING])
	end
	
	def on_event(event)
		service = Eggtooth::get_value(event.payload[:service], Array)
		return if !Eggtooth::equal_mixed(Compiler.to_s, service)
		if event.topic == Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED
		else
		end
	end

	def paths
		nil
	end

	def methods
		[EAM::METHOD_ALL]
	end
	
	# Since this is a fallback, just return 1
	def accept?(path_info)
		1
	end

	def exec(request, response)
		path_info = request.path_info
		method = path_info.method
		resource = path_info.resource
		component = component_resolve(resource)
		if component
			response.write "found component! #{component.script_resource(path_info, ['rb', 'eggshell']).inspect}"
		end
	end

	def component_resolve(resource)
		resourceType = resource.properties[PROP_RESOURCE_TYPE]
		type = resource.type
		compRes = nil
		if resourceType
			compRes = @resman.resolve(resourceType)
		else
			compRes = @resman.resolve("#{PATH_TYPE_ROOT}/#{type}")
		end
		
		if !compRes
			# @throw exception
		else
			return Component.new(compRes)
		end
	end

	module Compiler
		def compile(resource, path = nil)
		end

		# @return Class A 
		def get_class(path)
		end
		
		# @return Array The extensions handled by this compiler.
		def extensions
		end
	end
end

require_relative './script-action/component.rb'