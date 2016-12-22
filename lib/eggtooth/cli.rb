# Command line interface dispatcher.
class Eggtooth::CLI
	OPT_CUSTOM = '-X'
	OPT_PROPERTY = '-P'

	# Options beginning with '-' can either be a simple flag or expect a value in next element. there is no in-between
	@@ACTIONS = {
		'info' => {
		},
		'diff' => {
			:desc => 'Shows new/modified/deleted data'
		},
		'build' => {
			:desc => "Builds content from new/modified data",
			'env' => {:desc => 'Environment', :default => 'local', :expect_val => true, :norm => 'env'}, 
			'-e' => {:alias => 'env', :expect_val => true}
		},
		'push' => {
			:desc => "Publishes content to target environment(s)"
		}
	}

	# Generic format for arguments:
	#
	# pre.
	# eggtooth ACTION [-OPT] [OPT=VAL] FILE1 ... FILEN
	def self.parse(argv, extended_actions = {})
		# multiple commands can be run in sequence using '++' to delimit
		commands = [{:action => nil, :args => {}, :files => []}]
		idx = 0

		lkey = nil
		actdef = nil
		paramdef = nil

		argv.each do |arg|
			if idx == 0
				if !@@ACTIONS[arg]
					raise Exception.new("Action '#{arg}' not valid")
				end

				commands[-1][:action] = arg
				actdef = @@ACTIONS[arg]
			else
				if arg == '++'
					commands << {:action => nil, :args => {}, :files => []}
				elsif arg[0] == '-'
					paramdef = actdef[arg]
					if paramdef
						if paramdef[:expect_val]
							lkey = arg
						else
							commands[-1][:args][arg] = true
						end
					elsif arg[0..1] == '-X'
						# unspecified param
						key, val = arg.split('=', 2)
						val = true if !val
						commands[-1][:args][key] = val
					end
				elsif lkey
					key = paramdef[:alias] || lkey
					val = arg
					commands[-1][:args][key] = val
					lkey = nil
					paramdef = nil
				elsif arg.index('=')
					key, val = arg.split('=', 2)
					val = true if !val
					commands[-1][:args][key] = val
				else
					# once file is accepted, continue in file param mode?
					commands[-1][:files] << arg
				end
			end	
			idx += 1
		end
		
		return commands
	end
	
	USAGE_OPT = "%-15s%s"
	
	def self.usage(action = nil)
		str = []
		if !action
			str << "Valid actions (usage -h <action> for specific usage)"
			str << "-" * 40
			@@ACTIONS.each do |action, info|
				next if action.is_a?(Symbol)
				str << "#{action}\t-> #{info[:desc]}"
			end
		elsif @@ACTIONS[action]
			str << "Usage for action: #{action}"
			str << "-" * 40
			@@ACTIONS[action].each do |key, info|
				next if key.is_a?(Symbol)
				if info[:alias]
					extra = info[:expect_val] ? ' VALUE' : ''
					str << sprintf(USAGE_OPT, "#{key}#{extra}", "alias for '#{info[:alias]}'")
				else
					default = ''
					if info[:default]
						default = " (default: #{info[:default]})"
					end
					str << sprintf(USAGE_OPT, key, "#{info[:desc]}#{default}")
				end
			end
		end
		
		return str
	end

	def self.exec(commands)
		commands.each do |cmd|
			
		end
	end
end