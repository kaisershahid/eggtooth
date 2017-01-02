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
class Eggtooth::ActionManager::ScriptAction::RubyCompiler
	include Eggtooth::ActionManager::ScriptAction::Compiler
	CLASS_PREFIX = 'Eggtooth::ActionManager::ScriptAction::RubyCompiler::Compiled_'

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
	
	EXT = ['rb'].freeze
	
	def extensions
		EXT
	end
	
	# @param Eggtooth::ResourceManager::Resource
	# @param String path Alternate path to mape the resource class to.
	def compile(resource, path = nil)
		path = resource.path if !path
		fpath = "#{@root}#{path}"
		
#		puts "\t>>> compile: #{resource.path}"

		# @todo remove `||true`
		if !File.exists?(fpath) || true
			stream = resource.cast(IO)
			if stream != nil
				@class_cache.delete(path)
				src = stream.read

				clsfile = IO.read("#{File.dirname(__FILE__)}/ruby-compiler-compiled.rb")
				clsfile = clsfile.gsub(/%LINES%/, src)
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
			load("#{@root}#{path}")
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

		def init(context)
			@context = context
			@svcman = context['service_manager']
		end
	end
end

require 'fileutils'