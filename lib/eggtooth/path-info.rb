class Eggtooth::PathInfo
	def initialize(params)
		@path = params[:path]
		@extension = Eggtooth::get_value(params[:extension], '')
		@selectors = Eggtooth::get_value(params[:selectors], Array)
		@suffix = Eggtooth::get_value(params[:suffix], '')
		@method = Eggtooth::get_value(params[:method], '')
		@resource = Eggtooth::get_value(params[:resource], nil)
	end

	def path
	end

	def selectors
	end

	def extension
	end

	def suffix
	end

	def method
	end
	
	def resource
	end

	# Apply changes to this instance's data and return a new instance
	def modify(mods = {})
	end
end