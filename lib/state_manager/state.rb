require 'active_support/core_ext'

module StateManager
  class State

    # Represents the static specification of this state. This consists of all
    # child states and events. During initialization, the specification will
    # be read and the child states and events will be initialized.
    class Specification
      attr_accessor :states, :events, :initial_state

      def initialize
        self.states = {}
        self.events = {}
      end

      def initialize_copy(source)
        self.states = source.states.dup
        self.events = source.events.dup
      end

      def descendant_names
        res = []
        states.each do |state, specification_klass|
          res << state
          res.concat specification_klass.specification.descendant_names.map{|s| "#{state}.#{s}"}
        end
        res
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

    def entered
    end

    def exited
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

    def perform_event(name, *args)
      name = name.to_sym
      event = self.class.specification.events[name]
      result = send(name, *args) if respond_to?(name)
      transition_to(event[:transitions_to]) if event[:transitions_to]
      result
    end

    # Find all the states along the path
    def find_states(path)
      state = self
      parts = path.split('.')
      ret = []
      parts.each do |name|
        state = state.states[name.to_sym]
        ret << state
        return unless state
      end
      ret
    end

    # Returns the state at the given path
    def find_state(path)
      states = find_states(path)
      states && states.last
    end

    def leaf?
      states.empty?
    end

    # If an initial state is not explicitly specified, we choose the first leaf
    # state
    def initial_state
      if state = self.class.specification.initial_state
        find_state(state.to_s)
      elsif leaf?
        self
      else
        states.values.first.initial_state
      end
    end

    def self.create_resource_accessor!(name)
      unless method_defined?(name)
        define_method name do
          resource
        end
      end
      specification.states.values.each {|s|s.create_resource_accessor!(name)}
    end

    protected

    attr_writer :name, :states, :parent_state

    def method_missing(name, *args, &block)
      resource.send(name, *args, &block)
    end


  end
end
