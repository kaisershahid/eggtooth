class Eggtooth::ActionManager::ScriptAction::EggshellCompiler::Compiled___ext__sys__components__testComponent__testComponent_sel1_eggshell < Eggtooth::ActionManager::ScriptAction::EggshellCompiler::BaseCompiled
	def initialize()
		@lines = ["@et.header('content-type', 'text/plain')\n", "Hey hey hey... ${path_info}\n", "\n", "cooool\n", "\n", "@et.call('/node', {'path_info': {'extension': 'ext'}})"]
	end
end