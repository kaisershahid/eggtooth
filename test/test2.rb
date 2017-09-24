require_relative '../lib/eggtooth.rb'

map = {:a=>1, :b=>2}
aud = Eggtooth::ResourceManager::AuditedHash.new(map)
res = Eggtooth::ResourceManager::CoreFilesys::FileResource.new(nil, '/test', map, 'z', true)
#puts res.properties['1']
aud.each do |k,v|
	puts "#{k} - #{v}"
end