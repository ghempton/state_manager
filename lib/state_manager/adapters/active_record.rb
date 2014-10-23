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
                  table = conn.quote_table_name table_name
                  column = conn.quote_column_name klass._state_property
                  namespaced_col = "#{table}.#{column}"
                  query = "#{namespaced_col} = ? OR #{namespaced_col} LIKE ?"
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

              # Callback hooks
              after_commit(:on => :create) { state_managers.values.map(&:after_commit) }
              after_commit(:on => :update) { state_managers.values.map(&:after_commit) }
              before_save { state_managers.values.map(&:before_save) }
              after_save { state_managers.values.map(&:after_save) }
            end 
          end
        end

      end

      module ManagerMethods

        attr_accessor :pending_transition
        attr_accessor :uncommitted_transitions

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
            
            def send_event_with_lock!(*args)
              resource.with_lock do
                send_event_without_lock!(*args)
              end
            end
            alias_method_chain :send_event!, :lock
            
          end
        end

        def initialize(*)
          super
          self.uncommitted_transitions = []
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
          transition = pending_transition

          self.uncommitted_transitions << self.pending_transition
          self.pending_transition = nil

          _run_after_callbacks(*transition)
        end
        
        def after_commit
          transitions = self.uncommitted_transitions.dup
          
          self.uncommitted_transitions.clear

          transitions.each{ |t| run_commit_callbacks(*t) }
        end

        def run_commit_callbacks(from_state, to_state, current_event, enter_states, exit_states)
          exit_states.each{ |s| s.exit_committed if s.respond_to? :exit_committed }
          enter_states.each{ |s| s.enter_committed if s.respond_to? :enter_committed }
        end

        def write_state(value)
          resource.send :write_attribute, self.class._state_property, value.path
        end

        def persist_state
          resource.save!
        end
        
        def perform_initial_transition?
          !current_state || resource.new_record?
        end

      end
    end
  end
end
