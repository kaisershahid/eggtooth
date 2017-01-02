# Uses the resource manager to locate and execute the corresponding resource type script.
# The matching resource found to handle requests is referred to as a component (or component
# script).
#
# {{ScriptAction}} keeps track of {{Compiler}}s that translate a {{Component}} into an
# executable piece of code.
#
# Note that if a resource doesn't have its `egg:resourceType` or `egg:resourceSuperType` 
# property, its type is used and mapped to the directory {{/libs/components/default/$type}}.
#
# h2. Context Variables
#
# The following context variables are set at runtime:
#
# - {{service_manager}}
# - {{resource_manager}}: this uses the user's access restrictions (if implemented)
# - {{action_manager}}: needed?
# - {{request}}: current request (not the top-level)
# - {{response}}: current response (not necessarily the top-level)
# - {{resource}}: current resource
# - {{path_info}}: current path info
# - {{component}}: current component object
# - {{page_resource}}: top-level resource (the initial resource requested)
# - {{page_path_info}}: top-level path info
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
		@exts = []
		@compilers = {}
	end
	
	def on_event(event)
		service = Eggtooth::get_value(event.payload[:service], Array)
		return if !Eggtooth::equal_mixed(Compiler.to_s, service)
		if event.topic == Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED
			add_compiler(@svcman.get_by_sid(event.payload[:sid]))
		else
			remove_compiler(@svcman.get_by_sid(event.payload[:sid]))
		end
	end
	
	def add_compiler(compiler)
		compiler.extensions.each do |ext|
			@compilers[ext] = compiler
			@exts << ext
		end
	end
	
	def remove_compiler(compiler)
		compiler.extensions.each do |ext|
			@compilers.delete(ext)
			@exts.delete(ext)
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
#		puts ">> exec: #{path_info} // #{path_info.resource.path}"
		component = component_resolve(resource)
#		puts "\t>> component: #{component}\n"
		if component
			script = component.script_resource(path_info, ['rb', 'eggshell'])
#			puts "\t>> script: #{script.inspect}\n"
			if script
				inst = compile(script)
				if inst
					request.context['service_manager'] = @svcman
					request.context['resource_manager'] = resource.manager
					request.context['action_manager'] = self
					request.context['request'] = request
					request.context['response'] = response
					request.context['path_info'] = path_info
					request.context['resource'] = resource
					begin
						inst.init(request.context)
						inst.exec(request, response)
					rescue => ex
						response.write "#{ex}\n{#{ex.backtrace.join("\n\t")}"
					end
				end
			else
				# @todo throw 500
			end
		end
	end

	def component_resolve(resource)
		# @todo cache
		resourceType = resource.properties[PROP_RESOURCE_TYPE]
		type = resource.type
		compRes = nil
		if resourceType
			compRes = @resman.resolve(resourceType)
		else
			compRes = @resman.resolve("#{PATH_TYPE_ROOT}/#{type}")
		end

#		puts ">> component_resolve: #{resource.path} type=#{resourceType} ==> #{compRes.inspect}"
		if !compRes
			# @throw exception
		else
			return Component.new(compRes)
		end
	end
	
	def compile(script)
		ext = script.name.split('.').pop
		compiler = @compilers[ext]
		compiler.compile(script)
	end

	# Interface for interacting with a compiled script instance.
	module CompiledScriptContainer
		# @param Eggtooth::Client::Context context
		def init(context)
		end

		def exec(request, response)
		end
		
		def release
		end
	end

	# Interface for translating a script resource into an executable class.
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
require_relative './script-action/eggshell-compiler.rb'