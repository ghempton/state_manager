require 'active_support/core_ext'

module StateManager
  class State

    # Represents the static specification of this state. This consists of all
    # child states and events. During initialization, the specification will
    # be read and the child states and events will be initialized.
    class Specification
      attr_accessor :states, :events, :resource_class, :resource_name,
        :state_property, :initial_state

      def initialize
        self.states = {}
        self.events = {}
        self.state_property = :state
      end

      def initialize_copy(source)
        self.states = source.states.dup
        self.events = source.events.dup
        self.resource_class = source.resource_class
        self.resource_name = source.resource_name
        self.state_property = source.state_property
        self.initial_state = source.initial_state
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

    # Get the resource stored on the state manager
    def resource
      state_manager.resource
    end

    def transition_to(*args)
      state_manager.transition_to(*args)
    end

    def has_event?(name)
      name = name.to_sym
      !!self.class.specification.events[name]
    end

    def send_event(name, *args)
      name = name.to_sym
      event = self.class.specification.events[name]
      send(name, *args) if respond_to?(name)
      transition_to(event[:transitions_to]) if event[:transitions_to]
    end

    protected
    
    attr_writer :name, :states, :parent_state

  end
end