# Load each available adapter
require 'state_manager/adapters/base'
Dir["#{File.dirname(__FILE__)}/adapters/*.rb"].sort.each do |path|
  require "state_manager/adapters/#{File.basename(path)}"
end

module StateManager

  class AdapterNotFound < StandardError; end;

  module Adapters
    def self.match(klass)
      all.detect {|adapter| adapter.matches?(klass)}
    end

    def self.match_ancestors(ancestors)
      all.detect {|adapter| adapter.matches_ancestors?(ancestors)}
    end

    def self.find_by_name(name)
      all.detect {|adapter| adapter.integration_name == name} || raise(AdapterNotFound.new(name))
    end
    
    def self.all
      constants = self.constants.map {|c| c.to_s}.sort
      constants.map {|c| const_get(c)}
    end
  end

end