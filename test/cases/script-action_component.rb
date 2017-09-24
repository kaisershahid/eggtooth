class Eggtooth_ScriptAction_Component < Test::Unit::TestCase
	ESC = ::Eggtooth::ActionManager::ScriptAction
	COMP_ROOT = "/ext/sys/components"

	def setup
		@fwk = Eggtooth::Framework.get_instance('test')
		@resman = @fwk.resource_manager
		@res_child = @resman.resolve('sys/components/child')
		@res_child2 = @resman.resolve('sys/components/child2')
		@path_info_plain = @resman.path_info('/ext/dummy')
		@path_info_post = @resman.path_info('/ext/dummy.sel1.sel2.html', 'POST')
		@path_info_put = @resman.path_info('/ext/dummy.sel1.sel2.html', 'PUT')
		@path_info_html = @resman.path_info('/ext/dummy.sel1.sel2.html')
		@path_info_sel = @resman.path_info('/ext/dummy.sel1.sel2.ext')
		@path_info_sel1 = @resman.path_info('/ext/dummy.sel1.ext')
		@path_info_sel2 = @resman.path_info('/ext/dummy.sel2.ext')
		@ext = ['eggshell', 'rb']
	end
	
	def teardown
		
	end
	
	# Checks basic component inheritance.
	def test_basic
		child = ESC::Component.new(@res_child)
		child2 = ESC::Component.new(@res_child2)

		script0 = child.find_script('another_script.rb')
		script1 = child.find_script('script.eggshell')
		script2 = child.find_script('sel1.rb')
		script3 = child.script_resource(@path_info_plain, @ext)
		script4 = child2.script_resource(@path_info_plain, @ext)

		assert_true(script0 != nil, 'another_script.rb is nil')
		assert_equal('/ext/sys/components/child/another_script.rb', script0.path, 'another_script.rb not found in child')

		assert_true(script1 != nil, 'script.eggshell is nil')
		assert_equal('/ext/sys/components/child/script.eggshell', script1.path, 'script.eggshell not found in child')

		assert_true(script2 != nil, 'sel1.rb is nil')
		assert_equal('/ext/sys/components/parent/sel1.rb', script2.path, 'sel1.rb not found in parent')
		
		assert_true(script3 != nil, 'child: no script resource found')
		assert_equal('/ext/sys/components/child/child.eggshell', script3.path, 'child: did not map to default handler')

		assert_true(script4 != nil, 'child2: no script resource found')
		assert_equal('/ext/sys/components/parent/parent.rb', script4.path, 'child2: did not map to default parent handler')
	end
	
	# Does complex script matching
	def test_script_matching
		child = ESC::Component.new(@res_child)
		child2 = ESC::Component.new(@res_child2)
		
		c1_post_sel1 = child.script_resource(@path_info_post, @ext) # child/POST.sel1.rb
		c1_put = child.script_resource(@path_info_put, @ext) # child/sel1.rb
		c2_post = child2.script_resource(@path_info_post, @ext) # parent/POST.rb
		c2_put = child2.script_resource(@path_info_put, @ext) # child2/sel1.rb
		
		c1_sel1_sel2 = child.script_resource(@path_info_sel, @ext) # child/sel2.rb
		
		assert_equal("#{COMP_ROOT}/child/POST.sel1.rb", c1_post_sel1.path, "not expected script")
		assert_equal("#{COMP_ROOT}/child/sel2.rb", c1_put.path, "not expected script")
		
		assert_equal("#{COMP_ROOT}/parent/POST.rb", c2_post.path, "not expected script")
		assert_equal("#{COMP_ROOT}/child2/sel1.rb", c2_put.path, "not expected script")
		
		assert_equal("#{COMP_ROOT}/child/sel2.rb", c1_sel1_sel2.path, "not expected script")
	end
end