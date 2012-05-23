module StateManager
  # State helper methods. Examples:
  #
  #    @post.event! # send_event :event
  #    @post.active? # has_state :active
  #    @post.can_event? # respond_to_event? :event
  #
  module Helpers

    module Methods
      def self.define_methods(state_manager_class, target_class)
        self.define_methods_helper(state_manager_class, target_class, [])
      end

      def self.define_methods_helper(state_class, target_class, name_parts)
        state_class.events.each do |event|
          target_class.send :define_method, "#{event.to_s}!" do | *args |
            state_manager.send_event! event, *args
          end

          target_class.send :define_method, "can_#{event.to_s}?" do
            state_manager.respond_to_event?(event)
          end
        end

        state_class.states.each do |name, klazz|
          state_name_parts = name_parts.dup << name
          method = state_name_parts.join('_')
          path = state_name_parts.join('.')
          target_class.send :define_method, "#{method}?" do
            state_manager.in_state?(path)
          end

          define_methods_helper(klazz, target_class, state_name_parts)
        end
      end
    end

    def stateful(property, state_manager_klazz)
      define_method :state_manager do
        @state_manager ||= state_manager_klazz.new(self)
      end
      Methods.define_methods(state_manager_klazz, self)
    end

  end

  # Apply the helper methods to the state manager
  class Base
    # This method is used to make the helper methods compatible on the state
    # manager itself
    def state_manager
      self
    end

    @helpers_initialized = false
    class << self
      attr_accessor :helpers_initialized
    end

    alias_method :old_intialize, :initialize
    def initialize(target, options={})
      old_intialize(target, options)
      # We initialize the helpers here so that events and states defined in
      # sub-classes are picked up
      unless self.class.helpers_initialized
        Helpers::Methods.define_methods(self.class, self.class)
        self.class.helpers_initialized = true
      end
    end

  end
end