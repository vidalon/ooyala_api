require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new('ooyala_api', '0.1.0') do |p|
  p.description               = "Ooyala REST API client classes."
  p.url                       = "http://github.com/vidalon/ooyala_api"
  p.author                    = "Ooyala"
  p.email                     = "support@ooyala.com"
  p.ignore_pattern            = ["tmp/*", "script/*"] 
  p.development_dependencies  = []
end

Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each { |ext| load ext }