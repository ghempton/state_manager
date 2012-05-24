require 'state'

module StateManager
  module DSL
    def state(name, klazz=StateManager::State, &block)
      klazz = Class.new(klazz, &block)
      specification.states[name.to_sym] = klazz
    end

    def event(name, options={}, &block)
      specification.events << name.to_sym
      transitions_to = options[:transitions_to]
      # TODO check for pre-defined method
      define_method name do | manager, *args |
        result = instance_exec *args, &block if block
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