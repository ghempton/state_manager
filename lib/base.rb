require 'dsl'
require 'state'

module StateManager
 
  class StateNotFound < StandardError; end;
  class InvalidEvent < StandardError; end;

  # The base StateManager class is responsible for tracking the current state
  # of an object as well as managing the transitions between states.
  class Base < State

    class_attribute :initial_state
    attr_accessor :target, :options, :current_state
  
    def initialize(target, options={})
      super(nil, nil)
      self.target = target
      self.options = options

      read_initial_state
    end

    # Transitions to the state at the specified path. The path can be relative
    # to any state along the current state's path.
    def transition_to(path)
      state = current_state
      exit_states = []

      # Find the nearest parent state on the path of the current state which
      # has a sub-state at the given path
      new_states = find_states(state, path)
      while(!new_states) do
        exit_states << state
        state = state.parent_state
        raise(StateManager::StateNotFound, path) unless state
        new_states = find_states(state, path)
      end

      enter_states = new_states - exit_states
      exit_states = exit_states - new_states

      # Invoke the enter/exit callbacks
      exit_states.each{ |s| s.exit(self) }
      enter_states.each{ |s| s.enter(self) }

      self.current_state = enter_states.last
      write_state
    end

    # Find the states along the path from a start state
    def find_states(state, path)
      parts = path.split('.')
      ret = [state]
      parts.each do |name|
        state = state.states[name.to_sym]
        ret << state
        return unless state
      end
      ret
    end

    # Returns the state at the given path
    def find_state(path)
      states = find_states(self, path)
      states && states.last
    end

    # Send an event to the current state. This method will walk the current
    # state's path and find the first state which responds to the event.
    def send_event!(event, *args)
      state = find_state_for_event(event)
      raise(InvalidEvent, event) unless state
      state.send event, self, *args
    end

    def respond_to_event?(event)
      !!find_state_for_event(event)
    end

    def find_state_for_event(event)
      state = current_state
      while(state) do
        return state if state.respond_to?(event)
        state = state.parent_state
      end
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
      find_states(self, current_state.path).include? find_state(path) 
    end

    protected

    def read_initial_state
      self.current_state = if target.state
        find_state(target.state.to_s)
      elsif self.class.initial_state
        find_state(self.class.initial_state.to_s)
      else
        # TODO: ensure this is a leaf state
        states.first[1]
      end
    end

    def write_state
      target.state = current_state.path
    end

  end

end