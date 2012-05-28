module StateManager
  module Adapters
    module ActiveRecord
      include Base

      def self.matching_ancestors
        %w(ActiveRecord::Base)
      end

      module ResourceMethods

        def self.included(base)
          base.before_validation :write_initial_state
        end

        def write_initial_state
          # Accessing the state manager will ensure the the state attribute is set
          state_manager
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