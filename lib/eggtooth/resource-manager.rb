# Most interactions within the framework are mapped to a {{Resource}} context. A 
# resource is any type of data object -- the default implementation uses a local 
# file/directory hierarchy to map URLs and action handlers, but you could also
# use any type of database (assuming a {{Handler}} exists for it). The {{ResourceManager}}
# is responsible for locating and returning the requested resource, with optional
# restrictions determined by {{Eggtooth::AccessManager}}.
#
# Resources are resolved through a path. If the path is absolute, an exact match
# is attempted. If it's relative, a configurable set of roots are checked until
# a matching resource is found.
#
# Handlers can be assigned to specific branches. This means that there can be a 
# seamless mix of data from the local filesystem and external databases. Handlers
# also have an optional {{Editor}} which allows modifications to a resource 
# \[and controlled by {{Eggtooth::AccessManager}} constraints].
# 
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
		@log = Logging.logger[self]
		@handlers = []
		@root_paths = ['/ext', '/lib']
		@overlay_prefix = PATH_MERGE
		@handler_lib = nil
	end

	# @param String path
	# @param String resource_type If not null and a resource is found, apply this
	# resource type to it.
	# @todo take out is_exec support
	def resolve(path, resource_type = nil)
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
			@log.debug("resolving #{path} from roots")
			@handlers.each do |handler|
				if path.start_with?(handler.prefix)
					res = handler.get_resource(path)
					break if res
				end
			end
		end
		
		if res && resource_type
			res = ProxyResource.new(res, resource_type)
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
		@log = @fwk.logger(self)

		@root_paths = Eggtooth::get_value(attribs['root.paths'], Array)

		# initialize static mapping handlers
		mappings = Eggtooth::get_value(attribs['mappings'], Array)
		mappings.each do |mapping|
			prefix = mapping['prefix']
			hroot = @fwk.expression_eval(mapping['path'])
			@log.info("add mapping #{prefix} => #{hroot}")
			handler = CoreFilesys::FileHandler.new(prefix, hroot, self)
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
end

require_relative './resource-manager/core.rb'
require_relative './resource-manager/merged-resource.rb'
require_relative './resource-manager/core-filesys.rb'