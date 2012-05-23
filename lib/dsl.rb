require 'state'

module StateManager
  module DSL
    def state(name, klazz=StateManager::State, &block)
      klazz = Class.new(klazz, &block)
      self.states = self.states.dup
      self.states[name.to_sym] = klazz
    end

    def event(name, options={}, &block)
      self.events = self.events.dup
      self.events << name.to_sym
      transitions_to = options[:transitions_to]
      define_method name do | manager, *args |
        result = manager.instance_exec *args, &block if block
        if(transitions_to)
          manager.transition_to(transitions_to)
        end
        result
      end
    end
  end

  class State
    extend DSL
  end
end