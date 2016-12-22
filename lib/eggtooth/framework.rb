# Entry point for interacting with Eggtooth instance.
class Eggtooth::Framework
	#/*@ Standard expression variables
	E_PATH_INSTALL = "eggtooth.install"
	E_PATH_HOME = "eggtooth.home"
	E_PATH_CONTENT = "eggtooth.content"
	E_PATH_LIBS = "eggtooth.libs"
	E_PATH_VARS = "eggtooth.var"
	E_PATH_OUTPUT = "eggtooth.output"
	#@*/
	
	# @param Hash Run-time options for initialization. {{root}} can can be specified, which takes precedence
	# over environment {{EGGTOOTH_HOME}}. If neither is valid, uses current working directory.
	def initialize(id, opts = {})
		@id = id.clone.freeze
		@opts = opts
		@opts[:config] = {} if !opts[:config]
		@opts[:config]['dir.config'] = 'config' if !@opts[:config]['dir.config']

		root = opts[:root]
		root = ENV['EGGTOOTH_HOME'] if !root
		root = Dir.pwd if !root || root == ''
		@root = root[0] == '/' ? root : File.realdirpath(File.dirname(root))
		$stderr.write "> eggtooth root: #{@root}\n"
		
		@ee = Eggshell::Processor.new
		@ee.vars[E_PATH_HOME] = root
		@ee.vars[E_PATH_INSTALL] = Eggtooth::PATH_INSTALL

		@cfg_help = Eggtooth::ConfigHelper.new(@opts[:config])
		@cfg_help[E_PATH_INSTALL] = Eggtooth::PATH_INSTALL
		load_cfg('base')
		load_cfg(@opts[:env]) if @opts[:env]

		# normalize directories and set expression vars
		['libs','content','var','output'].each do |pathkey|
			key = "dir.#{pathkey}"
			path = @cfg_help[key]
			if !path
				path = "#{root}/#{pathkey}"
			else
				path = Eggtooth::resolve_path(path, root)
			end
			@cfg_help[key] = path
			@ee.vars["eggtooth.#{pathkey}"] = path
		end
		
		@svc_man = Eggtooth::ServiceManager.new
		@svc_man.add(self, {:sid => :framework})
	end

	private_class_method :new
	attr_reader :id

	def load_cfg(file)
		@cfg_help.merge_file("#{@root}/#{@opts[:config]['dir.config']}/#{file}.yaml")
		# @todo check & process :includes?
	end
	protected :load_cfg
	
	def service_manager
		@svc_man
	end

	# Initializes rest of framework and loads extensions. This can only be called once.
	def startup
		return if @started
		@started = true
		
		@res_man = Eggtooth::ResourceManager.new()
		@svc_man.add(@res_man, @cfg_help['resolver.manager'])
	end
	
	def shutdown
		# @todo shutdown hooks
		
		@svc_man = nil
		@res_man = nil
	end
	
	def resource_manager
		@res_man
	end
	
	def service_manager
		@svc_man
	end
	
	# Uses expression evaluator to expand interpolated vars and expressions
	def expression_eval(expr)
		@ee.expand_expr(expr)
	end

	@@instances = {}
	
	def self.get_instance(key = nil, opts = {})
		key = 'default' if !key
		
		if !@@instances[key]
			@@instances[key] = new(key, opts)
		end
		
		return @@instances[key]
	end
end	