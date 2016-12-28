require 'rake'
Gem::Specification.new do |s|
	s.bindir      = 'bin'
	s.name        = 'eggtooth'
	s.version     = '0.0.1'
	s.license     = 'MIT'
	s.summary     = "An application framework based on Apache Sling and using Eggshell."
	s.description = "An application framework based on Apache Sling and using Eggshell."
	s.authors     = ["Kaiser Shahid"]
	s.email       = 'kaisershahid@gmail.com'
	s.files       = FileList["bin/*", "lib/**/*.rb"]
	s.homepage    = 'https://acmedinotech.com/products/eggtooth'
	s.add_runtime_dependency "eggtooth", ["> 0.0.1"]
	s.add_runtime_dependency "rack", ["> 0.0.1"]
end