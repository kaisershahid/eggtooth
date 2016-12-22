module Eggtooth::ResourceManager::CoreFilesys
	ERM = Eggtooth::ResourceManager
	META_FILE =	'/.meta.yaml'
	PREFIX_META = '.meta'
	DIR_META = '/.meta'

	class Resource
		include ERM::Resource

		def initialize(handler, path, properties, filepath, is_meta = false)
			@handler = handler
			@path = path
			@properties = properties.clone.freeze
			@props_o = properties
			@filepath = filepath
			
			if is_meta
				@is_meta = true
				@type = properties[ERM::PROP_RESOURCE_TYPE]
				@type = properties[ERM::PROP_TYPE] if !@type
				@type = ERM::TYPE_NULL if !@type
			else
				@is_meta = false
				@type = ERM::TYPE_FILE
			end
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
		
		def children(&block)
			if @is_meta
				children = @handler._children(@filepath, &block)
			else
				[]
			end
		end
		
		def child(name)
			if @is_meta
				@handler._child(@filepath, @path, name)
			else
				nil
			end
		end
		
		def parent
			# @todo
		end
		
		def properties
			@properties
		end
		
		def inspect
			"<Resource #{@path} @ #{@type} | #{@properties}>"
		end
		
		def cast(object)
			if (object.is_a?(IO) || object == IO) && @type == ERM::TYPE_FILE
				# @todo read-only?
			end
		end
	end

	# This is the default handler to generate resource objects from the filesystem.
	# Given a path like {{/content/dir/resource.name}}, the following semantics are
	# followed:
	#
	# # If {{resource.name}} starts with `.meta.`, `nil` is returned.
	# # If {{resource.name +  '.yaml'}} exists, file is handled as a data file,
	# with parsed contents being returned for `properties()`.
	# ## Children of this resource should be in a directory named {{resource.name}}
	# # If {{resource.name}} ends with `.yaml`, the underlying file must end with 
	# `.static` or `nil` is returned.
	# # Otherwise, {{resource.name == filename}} results in either a normal file or directory.
	class Handler
		include ERM::Handler

		# @param String prefix The virtual path that should be handled with this instance.
		# @param String root The corresponding real path of the prefix.
		def initialize(prefix, root)
			@prefix = prefix.clone
			@prefixlen = prefix.length
			@root = root
		end
		
		def prefix
			@prefix
		end

		def get_resource(path)
			return nil if !path.start_with?(@prefix) || path.index(DIR_META) != nil

			# strip prefix for effective path
			epath = path == '/' ? '' : path[@prefixlen..-1]
			epath = "#{@root}/#{epath}"
			# check if yaml exists, otherwise assume normal file if exists
			_metaname = "#{epath}#{META_FILE}"
			if File.exists?(_metaname)
				props = YAML.load(IO.read(_metaname))
				return Resource.new(self, path, props, epath, true)
			elsif File.exists?(epath)
				return Resource.new(self, path, {}, epath)
			end

			return nil
		end

		def _children(root, &block)
			children = []
			if File.directory?(root)
				len = @root.length
				pathroot = root[len..-1]
				#pathroot = '/' if pathroot == ''
				last_res = nil

				Dir.new(root).each do |entry|
					next if entry == '.' || entry == '..'
					next if entry.start_with?(PREFIX_META)

					props = {}
					is_meta = false
					name = entry
					epath = "#{root}/#{entry}"
					_metaname = "#{epath}#{META_FILE}"
					if File.directory?(epath)
						next if !File.exists?(_metaname)
						is_meta = true
						props = YAML.load(IO.read("#{epath}#{META_FILE}"))
					end

					path = "#{pathroot}/#{name}"
					res = Resource.new(self, path, props, "#{pathroot}/#{entry}", is_meta)
					add = block != nil ? block.call(res) : true
					if add
						children << res
						last_res = res
					end
				end
			end
			children
		end
		
		def _child(root, path, name)
			return nil if name.start_with?(PREFIX_META)
			cpath = "#{root}/#{name}"
			if File.exists?(cpath)
				path = "#{path}#{path == '/' ? '' : '/'}#{name}"
				_metaname = "#{cpath}#{META_FILE}"
				if !File.directory?(cpath)
					return Resource.new(self, path, {}, cpath)
				elsif File.exists?(_metaname)
					props = YAML.load(IO.read(_metaname))
					return Resource.new(self, path, props, cpath, true)
				end
			end
			nil
		end
	end
end