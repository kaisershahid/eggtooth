# Handles look-up and retrieval of resources in the framework. Actual work is done
# by specific handlers -- the manager handles the delegation, and might do specific
# high-level filtering before any handlers are called.
#
# Resources will often map to specific scripts and other files in Eggtooth, but
# handlers can be used to map data to external data sources or even on-the-fly 
# temporary data.
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
		@root_paths = ['/ext', '/lib']
		@overlay_prefix = PATH_MERGE
		@handler_lib = nil
	end

	# @todo take out is_exec support
	def resolve(path)
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

		res
	end

	# Decomposes a path into its constituent parts. See {{PathInfo}} for more details.
	def path_info(path, method = nil)
		parts = path[1..-1].split('/')
		pathnew = ''
		last_res = resolve('/')

		selectors = []
		ext = nil
		
		idx = 0
		parts.each do |part|
			idx += 1
			subparts = part.split('.')

			name_matches = {}
			name = subparts.shift
			nametmp = name
			name_matches[name] = false
			subparts.each do |selector|
				nametmp += ".#{selector}"
				name_matches[nametmp] = false
			end

			candidates = last_res.children do |child|
				if name_matches.has_key?(child.name)
					name_matches[child.name] = child
					true
				else
					false
				end
			end

			if candidates.length > 0
				if name_matches[part]
					# longest possible match, so continue on to check next level
					last_res = name_matches[part]
				else
					# not longest possible match, so find longest among candidates
					if candidates.length > 1
						child = nil
						candidates.each do |candi|
							if child == nil
								child = candi
							elsif candi.name.length > child.name.length
								child = candi
							end
						end
						last_res = child
					else
						last_res = candidates[0]
					end
					selectors = part[last_res.name.length+1..-1].split('.')
					ext = selectors.pop
					break
				end
			else
				break
			end
		end

		# remaining parts considered as suffix
		suffix = parts[idx..-1].join('/')
		if suffix != ''
			suffix = "/#{suffix}"
		end
		
		return PathInfo.new({:path => last_res.path, :selectors => selectors, :extension => ext, :suffix => suffix, :resource => last_res, :method => method})
	end

	# Service activation via framework.
	def svc_activate(svc_man, attribs = {})
		@svc_man = svc_man
		@svc_man.add_event_listener(self, Eggtooth::ServiceManager::TOPIC_SERVICE_REGISTERED)
		@fwk = @svc_man.get_by_sid(:framework)

		@root_paths = Eggtooth::get_value(attribs['root.paths'], Array)

		# initialize static mapping handlers
		mappings = Eggtooth::get_value(attribs['mappings'], Array)
		mappings.each do |mapping|
			prefix = mapping['prefix']
			hroot = @fwk.expression_eval(mapping['path'])
			handler = CoreFilesys::Handler.new(prefix, hroot, self)
			add_handler(handler)
		end
	end

	# Service deactivation via framework.
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

	# Encapsulates a piece of data.
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
			@path = params[:path]
			@extension = Eggtooth::get_value(params[:extension], '')
			@selectors_raw = Eggtooth::get_value(params[:selectors], Array)
			@selectors = @selectors_raw.join('.')
			@suffix = Eggtooth::get_value(params[:suffix], '')
			@method = Eggtooth::get_value(params[:method], '')
			@resource = params[:resource]
		end

		def path
			@path.clone
		end
		
		def selectors_raw
			@selectors_raw.clone
		end

		def selectors
			@selectors.clone
		end

		def extension
			@extension.clone
		end

		def suffix
			@suffix.clone
		end

		def method
			@method.clone
		end
		
		def resource
			@resource
		end

		# Apply changes to this instance's data and return a new instance.
		# @todo fill in
		def modify(mods = {})
		end
	end
end

require_relative './resource-manager/merged-resource.rb'
require_relative './resource-manager/core-filesys.rb'