module StateManager
  # State helper methods. Examples:
  #
  #    @post.event! # send_event! :event
  #    @post.active? # in_state? :active
  #    @post.can_event? # respond_to_event? :event
  #
  module Helpers

    module Methods
      def self.define_methods(specification, target_class, property)
        self.define_methods_helper(specification, target_class, [], property)
      end

      def self.define_methods_helper(specification, target_class, name_parts, property)
        sm_proc = Proc.new do
          self.send "#{property}_manager"
        end

        specification.events.each do |name, event|
          target_class.send :define_method, "force_#{name.to_s}!" do | *args |
            state_manager = instance_eval &sm_proc
            state_manager.force_send_event! name, *args
          end

          target_class.send :define_method, "#{name.to_s}!" do | *args |
            state_manager = instance_eval &sm_proc
            state_manager.send_event! name, *args
          end

          target_class.send :define_method, "can_#{name.to_s}?" do
            state_manager = instance_eval &sm_proc
            state_manager.respond_to_event?(name)
          end
        end

        specification.states.each do |name, child_class|
          state_name_parts = name_parts.dup << name
          method = state_name_parts.join('_')
          path = state_name_parts.join('.')
          target_class.send :define_method, "#{method}?" do
            state_manager = instance_eval &sm_proc
            state_manager.in_state?(path)
          end

          define_methods_helper(child_class.specification, target_class, state_name_parts, property)
        end
      end
    end

  end
end