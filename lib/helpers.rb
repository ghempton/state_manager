module StateManager
  # State helper methods. Examples:
  #
  #    @post.event! # send_event! :event
  #    @post.active? # in_state? :active
  #    @post.can_event? # respond_to_event? :event
  #
  module Helpers

    module Methods
      def self.define_methods(specification, target_class)
        self.define_methods_helper(specification, target_class, [])
      end

      def self.define_methods_helper(specification, target_class, name_parts)
        specification.events.each do |event|
          target_class.send :define_method, "#{event.to_s}!" do | *args |
            state_manager.send_event! event, *args
          end

          target_class.send :define_method, "can_#{event.to_s}?" do
            state_manager.respond_to_event?(event)
          end
        end

        specification.states.each do |name, klazz|
          state_name_parts = name_parts.dup << name
          method = state_name_parts.join('_')
          path = state_name_parts.join('.')
          target_class.send :define_method, "#{method}?" do
            state_manager.in_state?(path)
          end

          define_methods_helper(klazz.specification, target_class, state_name_parts)
        end
      end
    end

  end

  # Apply the helper methods to the state manager
  class Base

    @helpers_initialized = false
    class << self
      attr_accessor :helpers_initialized
    end

    alias_method :old_intialize, :initialize
    def initialize(*args)
      old_intialize(*args)
      # We initialize the helpers here so that events and states defined in
      # sub-classes are picked up
      unless self.class.helpers_initialized
        Helpers::Methods.define_methods(self.class.specification, self.class)
        self.class.helpers_initialized = true
      end
    end

  end
end