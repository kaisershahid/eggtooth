# Entry point for interacting with Eggtooth instance.
class Eggtooth::Framework
	#/*@ Standard expression variables
	E_PATH_INSTALL = "eggtooth.install"
	E_PATH_HOME = "eggtooth.home"
	E_PATH_REPOSITORY = "eggtooth.repository"
	E_PATH_CONTENT = "eggtooth.content"
	E_PATH_LIBS = "eggtooth.libs"
	E_PATH_VARS = "eggtooth.var"
	E_PATH_OUTPUT = "eggtooth.output"
	E_PATH_LOG = "eggtooth.log"
	#@*/
	
	# @param Hash Run-time options for initialization. {{root}} can can be specified, which takes precedence
	# over environment {{EGGTOOTH_HOME}}. If neither is valid, uses current working directory.
	def initialize(id, opts = {})
		@id = id.clone.freeze
		@opts = opts
		@opts.symbolize_keys
		@opts[:config] = {} if !opts[:config]
		@opts[:config]['dir.config'] = 'config' if !@opts[:config]['dir.config']
		@opts[:runmode] = 'local' if !@opts[:runmode]

		root = opts[:root]
		root = ENV['EGGTOOTH_HOME'] if !root
		root = Dir.pwd if !root || root == ''
		@root = root[0] == '/' ? root : Eggtooth.resolve_path(root, Dir.pwd)

		@ee = Eggshell::Processor.new
		@ee.vars[E_PATH_HOME] = root
		@ee.vars[E_PATH_INSTALL] = Eggtooth::PATH_INSTALL

		@cfg_help = Eggtooth::ConfigHelper.new(@opts[:config])
		@cfg_help[E_PATH_INSTALL] = Eggtooth::PATH_INSTALL
		load_cfg('base')
		@opts[:runmode].split(',').each do |runmode|
			load_cfg(runmode)
		end

		# normalize directories and set expression vars
		['repository', 'libs','content','var','output', 'log'].each do |pathkey|
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
		
		# set base logger configs
		# @todo read from config (maybe as service instances?)
		@log = Logging.logger[@id]
		stdout = Logging.logger("#{@id}::stdout")
		stderr = Logging.logger("#{@id}::stderr")

		if !@opts[:log_std]
			@log.add_appenders(Logging.appenders.file("#{@ee.vars['eggtooth.log']}/eggtooth.log"))

			stdout.add_appenders(Logging.appenders.file("#{@ee.vars['eggtooth.log']}/stdout.log"))
			$stdout.reopen("#{@ee.vars['eggtooth.log']}/stdout.log")

			stderr.add_appenders(Logging.appenders.file("#{@ee.vars['eggtooth.log']}/stderr.log"))
			$stderr.reopen("#{@ee.vars['eggtooth.log']}/stderr.log")
		else
			@log.level = :info
			@log.add_appenders(Logging.appenders.stdout)
		end
		
		puts ">> appenders: #{@log.appenders.join("\n")}"
		
		@svc_man = Eggtooth::ServiceManager.new(logger('Eggooth::ServiceManager'))
		@svc_man.add(self, {:sid => :framework})
		
		stderr.info "<< framework: #{@id} => #{@root} >>"
	end
	
	attr_reader :log

	# Returns a framework-specific logger, with its root under the framework id. This allows
	# multiple framework instances to keep separate logs.
	def logger(key)
		key = key.class if !key.is_a?(String) && !key.is_a?(Class)
		Logging.logger["#{@id}::#{key.is_a?(Class) ? key.to_s : key}"]
	end

	private_class_method :new
	attr_reader :id

	def load_cfg(file)
		@cfg_help.merge_file("#{@root}/#{@opts[:config]['dir.config']}/#{file}.yaml")
		# @todo check & process :includes?
	end
	protected :load_cfg
	
	# Initializes rest of framework and loads extensions. This can only be called once.
	def startup
		return if @started
		@started = true
		
		@res_man = Eggtooth::ResourceManager.new()
		@svc_man.add(@res_man, @cfg_help['resolver.manager'])

		@dispatcher = Eggtooth::Dispatcher.new
		@action_man = Eggtooth::ActionManager.new
		@script_act = Eggtooth::ActionManager::ScriptAction.new(self, @cfg_help['script.action'])

		@svc_man.add(@dispatcher, {:sid => 'dispatcher'})
		@svc_man.add(@action_man, {:sid => 'action.manager'})
		@svc_man.add(@script_act, {:sid => 'action.impl.script'})

		if @cfg_help['services'].is_a?(Array)
			@cfg_help['services'].each do |attribs|
				@svc_man.activate(attribs)
			end
		end
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
	
	def dispatcher
		@dispatcher
	end
	
	def action_manager
		@action_manager
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