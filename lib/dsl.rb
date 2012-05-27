require 'state'

module StateManager
  module DSL

    # Specifies a state that is a child of the current state
    def state(name, base_class=nil, &block)
      # If no base class is specified we look for a class inside the current
      # state's class which has the same name as the state
      base_class ||= if self.const_defined?(name.capitalize)
        self.const_get(name.capitalize)
      else
        StateManager::State
      end
      klass = Class.new(base_class, &block)
      specification.states[name.to_sym] = klass
    end

    # Specifies an event on the current state
    def event(name, options={}, &block)
      name = name.to_sym
      specification.events << name
      transitions_to = options[:transitions_to]
      has_super = method_defined? name
      define_method name do | *args |
        result = super(*args) if has_super
        result = (instance_exec *args, &block if block) || result
        if(transitions_to)
          transition_to(transitions_to)
        end
        result
      end
    end
  end

  class State
    extend DSL
  end
end