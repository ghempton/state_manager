module StateManager
  module Resource

    def self.extended(base)
      base.instance_eval do
        class_attribute :state_managers
        self.state_managers = {}

        attr_accessor :state_managers
      end

      base.send :include, InstanceMethods
    end

    def state_manager(property=:state, klass=nil, options={}, &block)
      default_options = {:helpers => true}
      options = default_options.merge(options)

      klass ||= begin
        "#{self.name}States".constantize
      rescue NameError
        nil
      end
      klass ||= StateManager::Base

      # Create a subclass of the specified state manager and mixin an adapter
      # if a matching one is found
      this = self
      adapter = Adapters.match(self)
      resource_name = self.name.demodulize.underscore
      
      klass = Class.new(klass) do
        state_property property
        resource_class this
        resource_name resource_name
        include adapter.const_get('ManagerMethods') if adapter
        class_eval &block if block
      end
      include adapter.const_get('ResourceMethods') if adapter

      # Callbacks
      state_manager_added(property, klass, options) if respond_to? :state_manager_added
      klass.added_to_resource(self, property, options)

      # Define the subclass as a constant. We do this for multiple reasons, one
      # of which is to allow it to be serialized to YAML for delayed_job
      const_name = "#{property.to_s.camelize}States"
      remove_const const_name if const_defined?(const_name)
      const_set(const_name, klass)

      # Create an accessor for the state manager on this resource
      state_managers[property] = klass
      property_name = "#{property.to_s}_manager"
      define_method property_name do
        self.state_managers ||= {}
        state_manager = state_managers[property]
        unless state_manager
          state_manager = klass.new(self)
          state_managers[property] = state_manager
        end
        state_manager
      end

      # Define the helper methods on the resource
      Helpers::Methods.define_methods(klass.specification, self, property) if options[:helpers]
    end

    module InstanceMethods
      # Ensures that all properties with state managers are in valid states
      def validate_states!
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

  end
end