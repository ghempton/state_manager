module StateManager
 
  class StateNotFound < StandardError; end;
  class InvalidEvent < StandardError; end;
  class InvalidTransition < StandardError; end;

  # The base StateManager class is responsible for tracking the current state
  # of an object as well as managing the transitions between states.
  class Base < State

    class_attribute :_resource_class
    class_attribute :_resource_name
    class_attribute :_state_property
    self._state_property = :state

    attr_accessor :resource, :context

    def initialize(resource, context={})
      super(nil, nil)
      self.resource = resource
      self.context = context

      transition_to(initial_state.path) unless current_state
    end

    # Transitions to the state at the specified path. The path can be relative
    # to any state along the current state's path.
    def transition_to(path)
      path = path.to_s
      state = current_state || self
      exit_states = []

      # Find the nearest parent state on the path of the current state which
      # has a sub-state at the given path
      new_states = state.find_states(path)
      while(!new_states) do
        exit_states << state
        state = state.parent_state
        raise(StateNotFound, path) unless state
        new_states = state.find_states(path)
      end

      # Can only transition to leaf states
      # TODO: transition to the initial_state of the state?
      raise(InvalidTransition, path) unless new_states.last.leaf?

      enter_states = new_states - exit_states
      exit_states = exit_states - new_states

      from_state = current_state
      to_state = enter_states.last

      # Before Callbacks
      will_transition(from_state, to_state, current_event)
      exit_states.each{ |s| s.exit }
      enter_states.each{ |s| s.enter }

      # Set the state on the underlying resource
      self.current_state = to_state

      # After Callbacks
      exit_states.each{ |s| s.exited }
      enter_states.each{ |s| s.entered }
      did_transition(from_state, to_state, current_event)
    end

    def current_state
      path = read_state
      find_state(path) if path && !path.empty?
    end

    def current_state=(value)
      write_state(value)
    end

    # Send an event to the current state.
    #
    # Unlike the regular send_event method, this method recursively walks the
    # path of states starting at the current state.
    def send_event!(name, *args)
      self.current_event = name
      state = find_state_for_event(name)
      raise(InvalidEvent, name) unless state
      state.send_event name, *args
      self.current_event = nil
    end

    def respond_to_event?(name)
      !!find_state_for_event(name)
    end

    def find_state_for_event(name)
      state = current_state
      while(state) do
        return state if state.has_event?(name)
        state = state.parent_state
      end
    end

    def state_manager
      self
    end

    def to_s
      "#{current_state.path}" if current_state
    end

    # Returns true if the underlying object is in the state specified by the
    # given path. An object is 'in' a state if the state lies at any point of
    # the current state's path. E.g:
    #
    #     state_manager.current_state.path # returns 'outer.inner'
    #     state_manager.in_state? 'outer' # true
    #     state_manager.in_state? 'outer.inner' # true
    #     state_manager.in_state? 'inner' # false
    #
    def in_state?(path)
      self.find_states(current_state.path).include? find_state(path) 
    end

    # These methods can be overriden by an adapter
    def write_state(value)
      resource.send "#{self.class._state_property.to_s}=", value.path
    end

    def read_state
      resource.send self.class._state_property
    end

    def will_transition(from, to, event)
    end

    def did_transition(from, to, event)
    end

    # All events the current state will respond to
    def available_events
      state = current_state
      ret = {}
      while(state) do
        ret = state.class.specification.events.merge(ret)
        state = state.parent_state
      end
      ret
    end

    def self.infer_resource_name!
      return if _resource_name
      if name =~ /States/
        self._resource_name = name.demodulize.gsub(/States/, '').underscore
        create_resource_accessor!(_resource_name)
      end
    end

    def self.inherited(base)
      super(base)
      base.infer_resource_name!
    end

    def self.added_to_resource(klass, property, options)
    end

    protected

    attr_accessor :current_event

  end

end