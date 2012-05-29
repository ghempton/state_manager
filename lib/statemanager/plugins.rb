# Load each available plugin
Dir["#{File.dirname(__FILE__)}/plugins/*.rb"].sort.each do |path|
  require "statemanager/plugins/#{File.basename(path)}"
end