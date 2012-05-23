require 'dsl'
require 'active_support/core_ext'

module StateManager
  class State

    class_attribute :states
    self.states = {}

    class_attribute :events
    self.events = []

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

    # String representing the path of the current state, e.g.:
    # 'parentState.childState'
    def path
      path = name.to_s
      path = "#{parent_state.path}.#{path}" if parent_state && parent_state.name
      path
    end

    # Array of all states along the path (including this state)
    def path_states
      state = self
      ret = []
      while(state.parent_state) do
        ret << state
        state = state.parent_state
      end
      ret
    end

    def enter(manager)
    end

    def exit(manager)
    end

    protected
    
    attr_writer :name, :states, :parent_state

  end
end