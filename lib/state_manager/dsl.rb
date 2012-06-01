require 'active_support/core_ext'

module StateManager
  module DSL

    module State
      # Specifies a state that is a child of the current state
      def state(name, klass=nil, &block)
        # If no base class is specified we look for a class inside the current
        # state's class which has the same name as the state
        const_name = name.capitalize
        klass ||= if const_defined?(const_name)
          self.const_get(name.capitalize)
        else
          Class.new(StateManager::State)
        end
        klass = Class.new(klass, &block) if block

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
        def self.spec_property(name)
          class_eval do
            define_method name do |value|
              specification.send "#{name}=", value
            end
          end
        end
      end

      # The initial state
      def initial_state(value)
        specification.initial_state = value
      end
    end

    module Base
      def resource_class(value)
        self._resource_class = value
      end

      def resource_name(value)
        self._resource_name = value
        create_resource_accessor!(_resource_name)
      end

      def state_property(value)
        self._state_property = value
      end
    end
    
  end

  class State
    extend DSL::State
  end

  class Base
    extend DSL::Base
  end

end