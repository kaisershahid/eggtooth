require 'test/unit/testsuite'
require 'test/unit/testcase'

require_relative '../lib/eggtooth.rb'

$framework = Eggtooth::Framework.get_instance('test', {:root => '.', :log_std => true})
$framework.startup

#require_relative './cases/service-manager.rb'
#require_relative './cases/resource-manager.rb'
#require_relative './cases/script-action.rb'
require_relative './cases/script-action_component.rb'
require_relative './cases/actions-post.rb'