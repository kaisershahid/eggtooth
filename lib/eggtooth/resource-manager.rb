# Handles look-up and retrieval of resources in the framework. Actual work is done
# by specific handlers -- the manager handles the delegation, and might do specific
# high-level filtering before any handlers are called.
#
# @todo when adding new handlers, remove old handler if a prefix directly collides
class Eggtooth::ResourceManager
	include Eggtooth::ServiceManager::Events::EventListener
	
	PROP_TYPE = 'egg:type'
	PROP_RESOURCE_TYPE = 'egg:resourceType'
	PROP_RESOURCE_SUPERTYPE = 'egg:resourceSuperType'
	PROP_MERGE_HIDE_PROPS = 'egg:hideProps'
	PROP_MERGE_HIDE_CHILDREN = 'egg:hideChildren'

	TYPE_NULL = 'null'
	TYPE_FILE = 'fs:file'
	TYPE_FOLDER = 'fs:folder'

	# The canonical resource path for OOTB code
	PATH_LIB = '/lib'
	# The canonical resource path for merged resources. Can change with configuration
	PATH_MERGE = '/merged'
	
	def initialize()
		@handlers = []
		@exec_paths = ['/lib', '/ext']
		@root_paths = ['/ext', '/lib']
		@overlay_prefix = PATH_MERGE
		@handler_lib = nil
	end
	
	# @todo take out is_exec support
	def resolve(path, is_exec = false)
		res = nil
		
		do_merge = false
		if path.start_with?(@overlay_prefix)
			do_merge = true
			path = path[@overlay_prefix.length+1..-1]
		end

		# for relative path, search each root prefix. if do_merge, return a merged resource view
		if path[0] != '/'
			@root_paths.each do |prefix|
				epath = "#{prefix}/#{path}"
				@handlers.each do |handler|
					if epath.start_with?(handler.prefix)
						res = handler.get_resource(epath)
						if res && do_merge && prefix != PATH_LIB && @handler_lib
							# set merged resource only if corresponding overlayed resource exists
							overlayed = @handler_lib.get_resource("#{PATH_LIB}/#{path}")
							if overlayed
								res = MergedResource.new(res, overlayed, @overlay_prefix)
							end
							break
						end
					end
				end
				
				break if res
			end
		else
			@handlers.each do |handler|
				if path.start_with?(handler.prefix)
					res = handler.get_resource(path)
					break if res
				end
			end
		end
		
		if is_exec && res
			can_exec = false
			@exec_paths.each do |prefix|
				if res.path.start_with?(prefix)
					can_exec = true
					break
				end
			end
			return nil if !can_exec
		end
		
		res
	end
	
	# Resolves the path against the approved executable roots.
	def resolve_exec(path)
		return resolve(path, true)
	end
	
	def svc_activate(svc_man, attribs = {})
		@svc_man = svc_man
		@svc_man.add_event_listener(self, Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED)
		@fwk = @svc_man.get_by_sid(:framework)

		@exec_paths = Eggtooth::get_value(attribs['exec.paths'], Array)
		@root_paths = Eggtooth::get_value(attribs['root.paths'], Array)

		# initialize static mapping handlers
		mappings = Eggtooth::get_value(attribs['mappings'], Array)
		mappings.each do |mapping|
			prefix = mapping['prefix']
			hroot = @fwk.expression_eval(mapping['path'])
			handler = CoreFilesys::Handler.new(prefix, hroot)
			add_handler(handler)
		end
	end
	
	def svc_deactivate(svc_man)
		@handlers.clear
		@fwk = nil
		@svc_man.remove_event_listener(self)
		@svc_man = nil
	end
	
	def add_handler(handler, rank = -1)
		# @todo insert by ranking?
		@handlers << handler
		if handler.prefix == PATH_LIB
			@handler_lib = handler
		end
	end
	
	def remove_handler(handler)
		h = @handlers.delete(handler)
		if h && h.prefix == PATH_LIB
			@handler_lib = nil
		end
	end

	# Listens for and adds/removes handlers
	def on_event(event)
		svctype = event.payload.is_a?(Hash) ? event.payload[:service] : ''
		svctype = [svctype] if svctype.is_a?(String)
		return if svctype.find_index(Handler.class) == nil

		if event.topic == Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED
			add_handler(@svc_man.get_by_sid(event.payload[:sid]), event.payload[:ranking])
		elsif event.topic == Eggtooth::ServiceManager::TOPIC_SERVICE_STOPPING
			remove_handler(@svc_man.get_by_sid(event.payload[:sid]))
		end
	end

	# Encapsulates the object from the resolved path.
	module Resource

		# The full path to the resource.
		def path
		end

		# The name portion of the path.
		def name
		end
		
		# High-level type of resource. This typically would refer to
		# the handler for the object, or if unavailable, a more generic
		# type like 'Folder' or 'File'.
		#
		# @return String the type of the resource.
		def type
		end
		
		# Meta attributes of the resource.
		def properties
		end

		# Returns the direct children of this resource.
		# @param Block block If given, it's passed the parameters {{resource}} and should evaluate to true or false.
		# @return A list of (potentially filtered) children
		def children(&block)
		end
		
		# Returns a child resource with the given name.
		# @return Resource `nil` if no child found.
		def child(name)
		end
		
		def parent
		end
		
		# Attempts to convert the given resource to some type. For instance, if
		# the underlying resource is a static file, you could potentially get
		# the stream by doing {{cast(IO)}}.
		#
		# @param Object object The type of object to cast resource to.
		# @return `nil` if cast is unspported.
		# @throw Exception if valid cast fails.
		def cast(object)
		end
	end
	
	# 
	module Handler
		# @return Resource `nil` if path is unhandled or resuroce not found.
		def get_resource(path)
		end
		
		# @return String The prefix handled by this instance.
		def prefix
		end
	end

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
	class MergedResource
		include Resource
		
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
end

require_relative './resource-manager/core-filesys.rb'