# Current iteration of eggshell compiler just makes a generic class with
# original source inlined as an array of strings. Long-term goals are to
# intelligently convert certain macros into code while maintaining Eggshell
# processing semantics.
# 
# - macros
# 	- {{et:header(key, val)}}
# 	- {{et:call(path[, {type: newResourceType, path_info: {mods}, params: {}}]}}: 
# 	- {{et:include}}
# 	- {{et:service}}
# - remove macros:
# 	- {{include}}
class Eggtooth::ActionManager::ScriptAction::EggshellCompiler
	include Eggtooth::ActionManager::ScriptAction::Compiler
	CLASS_PREFIX = 'Eggtooth::ActionManager::ScriptAction::EggshellCompiler::Compiled_'

	def initialize
	end

	def svc_activate(svcman, attribs = {})
		@svcman = svcman
		@fwk = svcman.get_by_sid(:framework)
		@root = @fwk.expression_eval(attribs[:root] || '${eggtooth.home}/var')
		@class_cache = {}
	end
	
	def svc_deactivate(svcman, attribs = {})
	end
	
	EXT = ['eggshell', 'eggs'].freeze
	
	def extensions
		EXT
	end
	
	# @param Eggtooth::ResourceManager::Resource
	# @param String path Alternate path to mape the resource class to.
	def compile(resource, path = nil)
		path = resource.path if !path
		fpath = "#{@root}#{path}.rb"
		
#		puts "\t>>> compile: #{resource.path}"

		# @todo remove `||true`
		if !File.exists?(fpath) || true
			stream = resource.cast(IO)
			if stream != nil
				@class_cache.delete(path)
				src = stream.readlines

				clsfile = IO.read("#{File.dirname(__FILE__)}/eggshell-compiler-compiled.rb")
				clsfile = clsfile.gsub(/@lines = %LINES%/, "@lines = #{src.inspect}")
				clsfile = clsfile.gsub(/%CLASSNAME%/, self.class.class_name(path))

				basedir = File.dirname(fpath)
				FileUtils.mkdir_p(basedir)

				f = File.new(fpath, 'w+')
				f.write(clsfile)
				f.close
				return get_class(path)
			else
				# @todo exception
			end
		else
			return get_class(path)
		end
	end
	
	# @todo cache class so we don't keep reloading
	def get_class(path)
		clsname = self.class.class_name(path)
		if !@class_cache[clsname] || true
			load("#{@root}#{path}.rb")
			eval("@class_cache['#{clsname}'] = #{clsname}")
		end
		@class_cache[clsname].new
	end

	def self.class_name(path)
		clsparts = path.split('/')
		clsparts[0] = CLASS_PREFIX
		clsparts.join('__').gsub(/\./, '_')
	end
	
	class BaseCompiled
		include Eggtooth::ActionManager::ScriptAction::CompiledScriptContainer
		include Eggshell::MacroHandler

		def init(context)
			@context = context
			@svcman = context['service_manager']
			# safemode determines which resolver to use. if origin is not from standard execution paths,
			# use the resource manager assigned to current user, otherwise, use root manager
			@safemode = !@context['path_info'].path.match(/^\/(lib|ext)/)
			if @safemode
				@resman = @context['resource_manager']
			else
				@resman = @context['service_manager'].get_by_sid('resource.manager')
			end

			@proc = Eggshell::Processor.new
			Eggshell::Bundles::Registry.attach_bundle('basics', @proc)
			@proc.unregister_macro('include')
			@proc.register_macro(self, 'et.header', 'et.call', 'et.include', 'et.service')
		end
		
		def process(buffer, macname, args, lines, depth)
			if macname == 'et.include'
				resource = @resman.resolve(args[0])
				if resource && resource.type == Eggtooth::ResourceManager::TYPE_FILE
					# @todo this isn't totally working! try with
					# ["Hey hey [*hey*]... ${path_info}\n", "test\n", "\n", "raw. @@et.include('/config/base.yaml')@@\n", "test\n", "@et.include('/config/base.yaml')@@"]
					# seems like an inline macro issue
					lines = resource.cast(IO).readlines
					buffer << @proc.process(lines)
				else
					#log.trace("Resource doesn't exist or isn't a file: #{args[0]} #{resource}")
				end
			elsif macname == 'et.call'
				path = args.shift
				opts = args.shift
				opts = {} if !opts
				resType = opts['type']
				resource = @context['path_info'].resource.manager.resolve(path, resType)

				pathMods = opts['path_info'] || {}
				pathMods.delete('path')
				pathMods['resource'] = resource
				path_info = @context['path_info'].modify(pathMods)
#				puts ">> compiled: et.call #{path_info}"
				params = opts['params'] || {}
				@svcman.get_by_sid('dispatcher').subrequest(@context['request'], @context['response'], path_info, params)
			elsif macname == 'et.header'
				key = args[0]
				val = args[1]
				if key
					@context['response'][key] = val
				end
			elsif macname == 'et.service'
				# @todo needed?...
			end
		end

		def exec(request, response)
			response['content-type'] = 'text/html'
			@context.each do |key,val|
				@proc.vars[key] = val
			end
			response.write(@proc.process(@lines))
		end
	end
end

require 'fileutils'