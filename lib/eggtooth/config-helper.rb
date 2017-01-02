class Eggtooth::ConfigHelper
	def initialize(default = {})
		@cfg = default || {}
	end
	
	# Does a semi-deep merge of keys in the following way:
	# 
	# # if an existing key and a new val are both arrays, append values
	# # if an existing key and a new val are both hashes, merge keys
	# # otherwise, overwrite old key with new val
	#
	# An optional block can be passed to handle the behavior of scenarios #1 and #2.
	#
	# @param Hash cfg The new configuration hash to merge.
	# @param Proc block Should accept {{type, hash, key, val}}, where
	# {{type}} is `:arr` (array-array) or `:map` (hash-hash),
	# {{hash}} is the config hash, {{key}} is the current key being 
	# merged, and {{val}} is the current value to merge. If {{block}}
	# is nil, the default behavior above applies.
	def merge(cfg, &block)
		cfg.each do |key,val|
			if @cfg[key].is_a?(Array) && val.is_a?(Array)
				if block
					yield :arr, @cfg, key, val
				else
					@cfg[key] += val
				end
			elsif @cfg[key].is_a?(Hash) && val.is_a?(Hash)
				if block
					yield :map, @cfg, key, val
				else
					@cfg[key].update(val)
				end
			else
				@cfg[key] = val
			end
		end
	end
	
	def merge_file(file,&block)
		if File.exists?(file)
			merge(YAML.load(IO.read(file)),&block)
		end
	end
	
	def []=(key, val)
		@cfg[key] = val
	end
	
	# Gets a value from the key.
	def [](key, default = nil)
		@cfg[key]
	end
	
	def has_key?(key)
		@cfg.has_key?(key)
	end
end