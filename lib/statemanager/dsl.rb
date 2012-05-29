module StateManager
  module DSL

    # Specifies a state that is a child of the current state
    def state(name, klass=nil, &block)
      # If no base class is specified we look for a class inside the current
      # state's class which has the same name as the state
      const_name = name.capitalize
      klass ||= if const_defined?(const_name)
        self.const_get(name.capitalize)
      else
        StateManager::State
      end
      klass = Class.new(klass, &block) if block

      # Define a helper method that aliases to resource. This method is based on
      # the name of the resource class
      klass.specification.resource_class = specification.resource_class
      if specification.resource_class
        klass.send :define_method, specification.resource_name do
          resource
        end
      end

      remove_const const_name if const_defined?(const_name)
      const_set(const_name, klass)

      specification.states[name.to_sym] = klass
    end

    # Specifies an event on the current state
    def event(name, options={}, &block)
      name = name.to_sym
      event = options.dup
      event[:name] = name
      specification.events[name] = event
      define_method name, &block if block
    end
  end

  class State
    extend DSL
  end
end