module StateManager
  module Adapters
    module ActiveRecord
      include Base

      def self.matching_ancestors
        %w(ActiveRecord::Base)
      end

      module ResourceMethods

        def self.included(base)
          # Make sure that the model is in a valid state before it is saved
          base.before_validation :_validate_states

          base.extend(ClassMethods)
        end

        def _validate_states
          self.validate_states!
        end

        module ClassMethods
          def state_manager_added(property, klass, options)
            class_eval do
              klass.specification.states.keys.each do |state|
                # The connection might not be ready when defining this code is
                # reached so we wrap in a lamda.
                scope state, lambda {
                  conn = ::ActiveRecord::Base.connection
                  column = conn.quote_column_name klass._state_property
                  query = "#{column} = ? OR #{column} LIKE ?"
                  like_term = "#{state.to_s}.%"
                  where(query, state, like_term)
                }
              end
            end 
          end
        end

      end

      module ManagerMethods

        def write_state(value)
          # Since new objects will have a nil state value, this method will be called
          # during instantiation. We want to hold off on writing to the database.
          if resource.new_record?
            resource.send :write_attribute, self.class._state_property, value.path
          else
            resource.send :update_attribute, self.class._state_property, value.path
          end
        end

      end
    end
  end
end