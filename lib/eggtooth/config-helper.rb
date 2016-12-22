class Eggtooth::ConfigHelper
	def initialize(default = {})
		@cfg = default || {}
	end
	
	def merge(cfg)
		cfg.each do |key,val|
			@cfg[key] = val
		end
	end
	
	def merge_file(file)
		if File.exists?(file)
			merge(YAML.load(IO.read(file)))
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