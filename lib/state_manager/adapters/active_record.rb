module StateManager
  module Adapters
    module ActiveRecord
      include Base

      def self.matching_ancestors
        %w(ActiveRecord::Base)
      end

      module ResourceMethods

        def self.included(base)
          base.before_validation :validate_state
        end

        # Make sure that the model is in a valid state before it is saved
        def validate_state
          self.state_managers ||= {}
          self.class.state_managers.each do |name, klass|
            # Simply ensuring that all of the state managers have been
            # instantiated will make the corresponding states valid
            unless state_managers[name]
              state_managers[name] = klass.new(self)
            end
          end
        end

      end

      module ManagerMethods

        def write_state(value)
          super(value)
          resource.save
        end

      end
    end
  end
end