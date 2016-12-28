# Takes 2 resources and merges properties/path structure, with `res1` being the override
# and `res2` being the overridden.
#
# Property merging follows two rules:
# 
# # if `res1.`{{PROP_MERGE_HIDE_PROPS}} contains a set of keys, those properties are 
# ignored
# # `res1` overrides `res2`
#
# Child merging follows a similar rule:
#
# # if `res1.`{{PROP_MERGE_HIDE_CHILDREN}} contains a set of keys, those children are 
# ignored
# # `res1` overrides `res2`
# 
# Note that at a minimum, `res1` is expected to be non-null.
class Eggtooth::ResourceManager::MergedResource
	include Eggtooth::ResourceManager::Resource
	
	def initialize(res1, res2, merge_prefix)
		@res1 = res1
		@res2 = res2
		@props = {}
		@_hprops = {}
		@_hchildren = {}
		
		set_props(res1)
		set_props(res2) if res2

		@merge_prefix = merge_prefix
		@path = @merge_prefix + res1.path[res1.path.index('/',1)..-1]
		@name = File.basename(@path)
	end
	
	def set_props(res)
		(@props[PROP_MERGE_HIDE_PROPS] || []).each do |key|
			@_hprops[key] = true
		end
		
		(@props[PROP_MERGE_HIDE_CHILDREN] || []).each do |key|
			@_hchildren[key] = true
		end
		
		res.properties.each do |key,val|
			if !@_hprops[key]
				if !@props.has_key?(key)
					@props[key] = val
				end
			end
		end
	end
	
	protected :set_props
	
	def path
		@path
	end
	
	def name
		@name
	end
	
	def type
		@res1.type
	end
	
	def parent
		# @todo
	end
	
	def children(&block)
		c1 = []
		c1map = {}
		c2 = []
		
		if @res1
			c1 = @res1.children(&block)
			idx = 0
			c1.each do |c|
				c1map[c.name] = idx
				idx += 1
			end
		end

		# res2 is the overlayed resource, so now is time to hide chilren.
		# for corresponding children, replace c1 entry with merged resource
		if @res2
			c2 = @res2.children do |res|
				if @_hchildren.has_key?(res.name)
					false
				else
					add = block != nil ? block.call(res) : true
					if add
						if c1map.has_key?(res.name)
							idx = c1map[res.name]
							c1[idx] = MergedResource.new(c1[idx], res, @merge_prefix)
							false
						else
							true
						end
					end
				end
			end
		end

		children = c1 + c2
		idx = 0
		children.each do |child|
			if !child.is_a?(MergedResource)
				children[idx] = MergedResource.new(child, nil, @merge_prefix)
			end
			idx += 1
		end
		
		children
	end
	
	def child(name)
		c1 = @res1.child(name)
		c2 = @_hchildren[name] ? nil : @res2.child(name)
		
		# implication of c2 == nil: inheritance is broken or c1 is defining new branch. as such, no further merged resource
		if c1
			MergedResource.new(c1, c2, @merge_prefix)
		else
			MergedResource.new(c2, nil, @merge_prefix)
		end
	end

	def properties
		@props.clone
	end

	def cast(type)
	end
end