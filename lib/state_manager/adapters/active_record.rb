module StateManager
  module Adapters
    module ActiveRecord

      class DirtyTransition < StandardError; end;

      include Base

      def self.matching_ancestors
        %w(ActiveRecord::Base)
      end

      module ResourceMethods

        def self.included(base)
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
              
              after_initialize do
                self.state_managers ||= {}
              end
              before_validation do
                validate_states!
              end
              before_save do
                state_managers.values.map(&:before_save)
              end
              
              save_callback = options[:save_callback] && options[:save_callback].to_sym
              if save_callback == :after_commit
                after_commit(:on => :create) { state_managers.values.map(&:after_save) }
                after_commit(:on => :update) { state_managers.values.map(&:after_save) }
              else # defaults to after_save
                after_save { state_managers.values.map(&:after_save) }
              end
            end 
          end
        end

      end

      module ManagerMethods

        attr_accessor :pending_transition

        def self.included(base)
          base.class_eval do
            alias_method :_run_before_callbacks, :run_before_callbacks
            alias_method :_run_after_callbacks, :run_after_callbacks

            # In the AR use case, we don't want to run any callbacks
            # until the model has been saved
            def run_before_callbacks(*args)
              self.pending_transition = args
            end

            def run_after_callbacks(*args)
            end
          end
        end  

        def transition_to(*args)
          raise(DirtyTransition, "Only one state transition may be performed before saving a record. This error could be caused by the record being initialized to a default state.") if pending_transition
          super
        end

        def before_save
          return unless pending_transition
          _run_before_callbacks(*pending_transition)
        end

        def after_save
          return unless pending_transition
          _run_after_callbacks(*pending_transition)
          self.pending_transition = nil
        end

        def write_state(value)
          resource.send :write_attribute, self.class._state_property, value.path
        end

        def persist_state
          resource.save
        end
        
        def perform_initial_transition?
          !current_state || resource.new_record?
        end

      end
    end
  end
end
