module StateManager
  module Resource

    def self.extended(base)
      base.instance_eval do
        class_attribute :state_managers
        self.state_managers = {}

        attr_accessor :state_managers
      end
    end

    def state_manager(property=:state, klass=nil, helpers=true, &block)
      klass ||= begin
        "#{self.name}States".constantize
      rescue NameError
        nil
      end
      klass ||= StateManager::Base
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

      # Define the subclass as a constant. We do this for multiple reasons, one
      # of which is to allow it to be serialized to YAML for delayed_job
      const_name = "#{property.to_s.camelize}States"
      remove_const const_name if const_defined?(const_name)
      const_set(const_name, klass)

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

      Helpers::Methods.define_methods(klass.specification, self, property) if helpers
    end

  end
end