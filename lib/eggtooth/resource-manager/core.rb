module Eggtooth
	class ResourceManager
		# Root exception for resource operations. The constructor accepts optional
		# {{path}} and {{operation}} parameters to give clearer context whenever possible.
		class ResourceException < Exception
			def initialize(msg, path = nil, operation = nil)
				msg += " (path=#{path}, operation=#{operation})"
				super(msg)
				@path = path
				@operation = operation
			end

			attr_reader :path, :operation
		end

		# A discrete piece of data.
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
		
			# Returns the parent resource.
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
			
			def editor
			end

			# Returns the resource manager.
			def manager
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

			# Returns the resource manager.
			def manager
			end
			
			# Creates a new resource. Note that you can use {{NonExistingResource}}. This
			# method can double as a copy operation when given an alternate path.
			# 
			# @param Resource resource The reference resource.
			# @param String path If given, creates the resource at that location.
			# @return Resource The newly created resource. This will never be the reference
			# resource.
			def add(resource, path = nil)
			end

			# Saves updates to the resource's properties.
			# @param Resource resource The reference resource.
			# @return Resource Handler can choose to return a new or the reference resource.
			# Always assume new resource for broadest compatibility.
			def modify(resource)
			end

			# Moves the given resource to a new parent, with the option to rename.
			# @param Object resource If {{Resource}}, uses the path from that. Otherwise,
			# a {{String}} is expected.
			# @param Object parent The parent resource or path.
			# @param String name If nil, uses the current resource's name.
			# @return Resource The newly moved resource.
			def move(resource, parent, name = nil)
			end

			# Removes a resource and its descendants.
			# @return Boolean True if successful. False otherwise.
			def delete(resource)
			end
		end

		# Encapsulates high-level write operations for a resource. This is tightly
		# bound to a {{Handler}}.
		module Editor
			# Creates a new resource. Note that you can use {{NonExistingResource}}. This
			# method can double as a copy operation when given an alternate path.
			# 
			# @param Resource resource The reference resource.
			# @param String path If given, creates the resource at that location.
			# @return Resource The newly created resource. This will never be the reference
			# resource.
			def add(resource, path = nil)
			end

			# Saves updates to the resource's properties.
			# @param Resource resource The reference resource.
			# @return Resource Handler can choose to return a new or the reference resource.
			# Always assume new resource for broadest compatibility.
			def modify(resource)
			end

			# Moves the given resource to a new parent, with the option to rename.
			# @param Object resource If {{Resource}}, uses the path from that. Otherwise,
			# a {{String}} is expected.
			# @param Object parent The parent resource or path.
			# @param String name If nil, uses the current resource's name.
			# @return Resource The newly moved resource.
			def move(resource, parent, name = nil)
			end

			# Removes a resource and its descendants.
			# @return Boolean True if successful. False otherwise.
			def delete(resource)
			end
			
			def reorder(parent, name, position_before = nil)
			end
		end
		
		# Use this if you need a resource that doesn't yet exist (e.g. when creating a new
		# resource, or doing some offline task).
		class NonExistingResource
			include Resource

			def initialize(path, manager = nil, props = {})
				@path = path
				@manager = manager
				@props = props
				@type = @props[PROP_RESOURCE_TYPE]
				@type = @props[PROP_TYPE] if !@type
				@type = TYPE_NULL if !@type
			end
			
			def path
				@path
			end
			
			def name
				File.basename(@path)
			end
			
			def type
				@type
			end
			
			def properties
				@props
			end
			
			def manager
				@manager
			end
			
			def parent
				nil
			end
			
			def cast(object)
				
			end
			
			# Generates a resource from an {{IO}} object.
			def self.from_io(io, path, manager = nil)
				props = {PROP_TYPE => TYPE_FILE, :cast => {IO => io}}
				return NonExistingResource.new(path, manager, props)
			end
		end
		
		# Use this to case one resource to another type.
		def ProxyResource
			def initialize(resource, newType)
				@resource = resource
				@newType = newType
			end
			
			def path
				@resource.path
			end
			
			def name
				@resource.name
			end
			
			def properties
				@resource.properties
			end
			
			def type
				@newType
			end
			
			def parent
				@resource.parent
			end
			
			def manager
				@resource.manager
			end
		end
		
		# A hash implementation that tracks updates to properties. This is useful for detecting
		# and saving changes.
		class AuditedHash
			def initialize(map)
				@map = map.is_a?(AuditedHash) ? map.map : map
				@log = []
			end

			# Called before a new value is set. Allows implementation to validate any changes,
			# throw exceptions on protected changes, etc.
			# @return Array If operation is allowed, a key-value pair. Otherwise, nil.
			def set_hook(key, val)
				[key, val]
			end
			
			def has_key?(key)
				@map.has_key?(key)
			end
			
			def [](key)
				@map[key]
			end

			def []=(key, val)
				hook = set_hook(key, val)
				if !hook
					return false
				end

				key, val = hook

				existed = @map.has_key?(key) && !@locked
				oval = @map[key]
				@map[key] = val
				
				if existed
					if val != oval
						@log << [:modify, key, oval]
					end
				else
					@log << [:add, key, val]
				end
			end
			
			def delete(key)
				existed = @map.has_key?(key) && !@locked
				val = @map[key]
				@map.delete(key)
				if existed
					@log << [:delete, key, val]
				end
				val
			end
			
			def each(&block)
				@map.each do |k,v|
					yield(k,v)
				end
			end
			
			def update(hash)
				return if !hash.is_a?(Hash)
				hash.each do |k,v|
					self[k] = v
				end
			end

			def map
				@map.clone
			end
			
			def changelog
				@log.clone
			end
			
			def clear
				# @todo
			end
			
			def dirty?
				changelog.length
			end
			
			def marshal_dump
				@map
			end
			
			def marshal_load(data)
				@map = data
			end
		end

		# {{PathInfo}} parses out the parts of a request path. In Eggtooth, the URL can be broken up
		# as follows (similar in terminology to [~ Sling's model ; https://sling.apache.org/documentation/the-sling-engine/url-decomposition.html ~]):
		#
		# pre.
		# /path/to/resource
		# /path/to/resource.extension
		# /path/to/resource.selector*.extension
		# /path/to/resource.selector*.extension/suffix
		# 
		# If we look at the resource name as being a set of words separated by a dot, we look for the 
		# longest matching set of words from the URL to the resource itself. If there's one word left over,
		# it's considered the [/extension/]. If there's two or more words left, the last word is the [/extension/],
		# and the remaining words are the [/selectors/]. If there's a slash beyond the resource name, that is 
		# considered the [/suffix/].
		#
		# These extra bits of the URL can potentially change the view of the resource you're requesting:
		# for instance, if a resource can be rendered as either PDF or HTML, handlers can be written for 
		# {{pdf}} and {{html}} extensions. If the resource is a search page, the selectors can contain
		# offsets and limits (e.g. {{search.0.100.html}} or {{search.offset=0.limit=100.html}}). If the resource
		# is a page editor, the suffix can be the path to an HTML file (e.g. {{/editor.html/path/to/actual/page.html}}).
		#
		# Note that [/extension/] in this sense has nothing to do with underlying resource. For instance,
		# if there's a resource named {{document.doc}}, there is no extension, but {{document.doc.pdf}} would have
		# an extension of {{pdf}}.
		class PathInfo
			
			def initialize(params)
				@props = {}
				@props[:path] = params[:path]
				@props[:extension] = Eggtooth::get_value(params[:extension], '')
				@props[:selectors_raw] = Eggtooth::get_value(params[:selectors], Array)
				@props[:selectors] = @props[:selectors_raw].join('.')
				@props[:suffix] = Eggtooth::get_value(params[:suffix], '')
				@props[:method] = Eggtooth::get_value(params[:method], '')
				@props[:resource] = params[:resource]
			end
			
			attr_reader :props
			protected :props
		
			def path
				@props[:path].clone
			end
			
			def selectors_raw
				@props[:selectors_raw].clone
			end

			def selectors
				@props[:selectors].clone
			end

			def extension
				@props[:extension].clone
			end

			def suffix
				@props[:suffix].clone
			end

			def method
				@props[:method].clone
			end
			
			def resource
				@props[:resource]
			end

			def to_s
				sel = @props[:selectors]
				sel = ".#{sel}" if sel != ''
				if @props[:extension] != ''
					sel = "#{sel}.#{@props[:extension]}"
				end
				"#{props[:path]}#{sel}#{@props[:suffix]}"
			end
			
			def inspect
				@props.inspect
			end

			# Apply changes to this instance's data and return a new instance. Aside from
			# all the keys supporter in the constructor, the following are also supported:
			#
			# - {{:delete}}: list of properties to set to empty.
			# - {{:add_selectors}}: list of selectors to append to current selectors.
			def modify(mods = {})
				npath = PathInfo.new(self.props)
				mods.symbolize_keys
				mods.each do |key, val|
					npath.props[key] = val
				end
				
				if mods[:resource]
					npath.props[:path] = mods[:resource].path
				elsif mods[:path]
					npath.props[:resource] = resource.manager.resolve(mods[:path])
				end
				
				if mods[:delete].is_a?(Array)
					mods[:delete].symbolize_vals
					mods[:delete].each do |key|
						if key == :selectors_raw || key == :selectors
							npath.props[:selectors_raw] = []
							npath.props[:selectors] = ''
						elsif key == :resource
							npath.props[key] = nil
						else
							npath.props[key] = ''
						end
					end
				end

				if mods[:add_selectors].is_a?(Array)
					npath.props[:selectors_raw] += mods[:add_selectors]
					npath.props[:selectors] = npath.props[:selectors_raw].join('.')
				end
				
				# @todo :selectors_raw is joined
				npath
			end
		end
	end
end