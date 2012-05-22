require 'dsl'
require 'pry'
require 'active_support/core_ext'

module StateManager
  class State

    class_attribute :states
    self.states = {}

    class << self
      include StateManager::DSL::State
    end

    attr_reader :name, :states, :parent_state

    def initialize(name=nil, parent_state=nil)
      self.name = name
      self.parent_state = parent_state
      self.class.states ||= {}
      self.states = self.class.states.inject({}) do |states, (name, klazz)|
        states[name] = klazz.new(name, self)
        states
      end
    end

    def path
      path = name.to_s
      path = "#{parent_state.path}.#{path}" if parent_state && parent_state.name
      path
    end

    def enter(manager)
    end

    def exit(manager)
    end

    protected
    
    attr_writer :name, :states, :parent_state

  end
end