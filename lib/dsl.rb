module StateManager
  module DSL

    module State

      def state(name, klazz=StateManager::State, &block)
        klazz = Class.new(klazz, &block)
        self.states = self.states.dup
        self.states[name.to_sym] = klazz
      end

      def event(name, options={}, &block)
        transitions_to = options[:transitions_to]
        define_method name do | *args |
          result = block.call(args) if block
          if(transitions_to)
            manager = args[0]
            manager.transition_to(transitions_to)
          end
          result
        end
      end

    end

  end
end