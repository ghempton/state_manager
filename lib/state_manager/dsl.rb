require 'active_support/core_ext'

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
      klass.specification.resource_name = specification.resource_name
      if specification.resource_name
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

    # Helper to simplify creating dsl reader methods for specification
    # properties
    module_eval do
      def self.spec_property(name, &block)
        class_eval do
          define_method name do |value|
            specification.send "#{name}=", value
          end
        end
        class_exec(name, &block) if block
      end
    end

    # The initial state
    spec_property :initial_state

    # The Model class for this state manager
    spec_property :resource_class

    # An alias for 'resource' that is accessible in all states
    spec_property :resource_name do |value|
      unless method_defined?(value)
        define_method value do
          resource
        end
      end
    end

    # The property on the resource to read/write state to
    spec_property :state_property
  end

  class State
    extend DSL
  end
end