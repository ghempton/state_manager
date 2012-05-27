require 'dsl'
require 'active_support/core_ext'

module StateManager
  class State

    # Represents the static specification of this state. This consists of all
    # child states and events. During initialization, the specification will
    # be read and the child states and events will be initialized.
    class Specification
      attr_accessor :states, :events

      def initialize
        self.states = {}
        self.events = []
      end

      def initialize_copy(source)
        self.states = source.states.dup
        self.events = source.events.dup
      end
    end

    class_attribute :specification
    self.specification = Specification.new

    def self.inherited(child)
      # Give all sublcasses a clone of this states specification. Subclasses can
      # add events and states to their specification without affecting the
      # parent
      child.specification = specification.clone
    end

    attr_reader :name, :states, :parent_state

    def initialize(name, parent_state)
      self.name = name
      self.parent_state = parent_state
      self.states = self.class.specification.states.inject({}) do |states, (name, klazz)|
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

    def enter
    end

    def exit
    end

    def to_s
      "#{path}"
    end

    def to_sym
      path.to_sym
    end

    def state_manager
      parent_state.state_manager
    end

    # Get the target stored on the state manager
    def target
      state_manager.target
    end
    alias :resource :target

    def transition_to(*args)
      state_manager.transition_to(*args)
    end

    protected
    
    attr_writer :name, :states, :parent_state

  end
end