require_relative '../lib/eggtooth.rb'

framework = Eggtooth::Framework.get_instance('test', {:root => '.', :log_std => true})
puts Eggtooth::PATH_INSTALL
puts "framework.id=#{framework.id}"

framework.startup

def crawl_resource(res)
	puts "-- crawling: #{res.path}"
	q = []
	res.children.each do |child|
		puts "   > #{child.name} : #{child.properties}"
		q << child.name if child.type != 'fs:file'
	end
	
	q.each do |cname|
		crawl_resource(res.child(cname))
	end
end

resman = framework.resource_manager
ext = resman.resolve('/ext')
dummy = Eggtooth::ResourceManager::NonExistingResource.new('/ext/dummy', nil, {'egg:type' => 'whatever', 'prop' => 'val'})
puts dummy.properties.inspect
puts dummy.properties.class
ext.editor.add(dummy)

pi_get = resman.path_info('/node.sel1.sel2.ext', 'GET')
pi_post = resman.path_info('/node.sel1.sel2.ext', 'POST')
puts "***" + pi_get.inspect
#puts "***" + pi_get.modify({:delete => ['selectors', 'resource']}).inspect
# actman = framework.service_manager.get_by_sid 'action.manager'
# action = actman.map(pi_get)
# action.exec(Eggtooth::Client::Request.new({}, pi_get, {}), nil)
# action.exec(Eggtooth::Client::Request.new({}, pi_post	, {}), nil)

# ext_sys = resman.resolve('/ext')
# puts ext_sys.class.to_s + " >> " + ext_sys.inspect
# crawl_resource(ext_sys)
# puts '***********'
# ext_sys = resman.resolve('sys')
# puts ext_sys.class.to_s + " >> " + ext_sys.inspect
# crawl_resource(ext_sys)

# puts '***********'
# ext_sys = resman.resolve('/merged/sys')
# puts ext_sys.class.to_s + " >> " + ext_sys.inspect
# crawl_resource(ext_sys)

# pathinfo = resman.path_info('/ext/sys.sel1.sel2.ext/suffix')
# puts pathinfo.inspect
# puts '**** action.default_rank check'
# puts Eggtooth::ActionManager::Action.default_rank(pathinfo, nil, ['sel1.sel2'], 'ext', nil)
# puts Eggtooth::ActionManager::Action.default_rank(pathinfo, nil, ['sel1'], 'ext', nil)
# puts Eggtooth::ActionManager::Action.default_rank(pathinfo, nil, ['sel1.sel2'], 'ext', '/suffix')
# puts Eggtooth::ActionManager::Action.default_rank(pathinfo, 'sys:folder', ['sel1.sel2'], 'ext', '/suffix')

#comp = Eggtooth::ActionManager::ScriptAction::EggshellCompiler.new(framework.service_manager, {:root => '${eggtooth.home}/var'})