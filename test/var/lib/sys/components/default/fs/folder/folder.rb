class Eggtooth::ActionManager::ScriptAction::RubyCompiler::Compiled___lib__sys__components__default__fs__folder__folder_rb < Eggtooth::ActionManager::ScriptAction::RubyCompiler::BaseCompiled
def exec(request, response)
	path_info = request.path_info
	resource = path_info.resource
	response['content-type'] = 'text/html'
	# @todo have some sort of control mechanism (either inherited prop 'http.access' or global framework flag for directory viewing)
	response.write "<h4>Directory listing for <b>#{resource.path}</b></h4><ul>"
	resource.children.each do |child|
		response.write "<li>#{child.name}</li>"
	end
	response.write "</ul>"
end
end