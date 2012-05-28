require 'dsl'
require 'state'

module StateManager
 
  class StateNotFound < StandardError; end;
  class InvalidEvent < StandardError; end;

  # The base StateManager class is responsible for tracking the current state
  # of an object as well as managing the transitions between states.
  class Base < State

    class_attribute :initial_state
    class_attribute :default_options
    self.default_options = {:state_property => :state}

    attr_accessor :resource, :options
  
    def initialize(resource, options={})
      super(nil, nil)
      self.resource = resource
      self.options = self.class.default_options.merge(options)

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
      new_states = find_states(state, path)
      while(!new_states) do
        exit_states << state
        state = state.parent_state
        raise(StateManager::StateNotFound, path) unless state
        new_states = find_states(state, path)
      end

      enter_states = new_states - exit_states
      exit_states = exit_states - new_states

      from_state = current_state
      to_state = enter_states.last
      will_transition(from_state, to_state, current_event)

      # Invoke the enter/exit callbacks
      exit_states.each{ |s| s.exit }
      enter_states.each{ |s| s.enter }

      self.current_state = to_state

      did_transition(from_state, to_state, current_event)
    end

    def will_transition(from, to, event)
    end

    def did_transition(from, to, event)
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

    def current_state
      path = read_state
      find_state(path) if path && !path.empty?
    end

    def initial_state
      if self.class.initial_state
        find_state(self.class.initial_state.to_s)
      else
        # TODO: ensure this is a leaf state
        states.first[1]
      end
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
      "#{self.class.name} in '#{current_state.path}'"
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

    # These methods can be overriden by an adapter
    def write_state(value)
      resource.send "#{options[:state_property].to_s}=", value.path
    end

    def read_state
      resource.send options[:state_property]
    end

    def self.initialize_resource_class!
      # First priority is the namespaced model, e.g. User::Group
      specification.resource_class ||= begin
        namespaced_class = self.name.sub(/States/, '')
        namespaced_class.constantize
      rescue NameError
        nil
      end

      # Second priority is the top namespace model, e.g. EngineName::Article for EngineName::Admin::ArticlesController
      specification.resource_class ||= begin
        namespaced_classes = self.name.sub(/States/, '').split('::')
        namespaced_class = [namespaced_classes.first, namespaced_classes.last].join('::')
        namespaced_class.constantize
      rescue NameError
        nil
      end

      # Third priority the camelcased c, i.e. UserGroup
      specification.resource_class ||= begin
        camelcased_class = self.name.sub(/States/, '').gsub('::', '')
        camelcased_class.constantize
      rescue NameError
        nil
      end

      if specification.resource_class
        self.send :define_method, specification.resource_name do
          resource
        end

        adapter = Adapters.match(specification.resource_class)
        include adapter.const_get('ManagerMethods') if adapter
      end
    end

    def self.inherited(base)
      super(base)
      base.send :initialize_resource_class!
    end

    protected

    attr_accessor :current_event

  end

end