require 'helpers'

# Load each available adapter
require 'adapters/base'
Dir["#{File.dirname(__FILE__)}/adapters/*.rb"].sort.each do |path|
  require "adapters/#{File.basename(path)}"
end

module StateManager

  class AdapterNotFound < StandardError; end;

  # This method is called on the resource class
  def stateful(property, state_manager_class=nil, helpers=true, options={})

    state_manager_class ||= "#{self.name}States".constantize

    define_method :state_manager do
      @state_manager ||= state_manager_class.new(self, options)
    end

    if adapter = Adapters.match(self)
      include adapter.const_get('ResourceMethods')
    end

    Helpers::Methods.define_methods(state_manager_class.specification, self) if helpers
  end

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