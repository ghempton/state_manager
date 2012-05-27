module StateManager
  module Adapters
    module Base

      module ClassMethods
        # The name of the adapter
        def adapter_name
          @adapter_name ||= begin
            name = self.name.split('::').last
            name.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
            name.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
            name.downcase!
            name.to_sym
          end
        end
        
        # Whether this adapter is available for the current library.  This
        # is only true if the ORM that the adapter is for is currently
        # defined.
        def available?
          matching_ancestors.any? && Object.const_defined?(matching_ancestors[0].split('::')[0])
        end
        
        # The list of ancestor names that cause this adapter to matched.
        def matching_ancestors
          []
        end
        
        # Whether the adapter should be used for the given class.
        def matches?(klass)
          matches_ancestors?(klass.ancestors.map {|ancestor| ancestor.name})
        end
        
        # Whether the adapter should be used for the given list of ancestors.
        def matches_ancestors?(ancestors)
          (ancestors & matching_ancestors).any?
        end
      end

      def self.included(base)
        return if base < StateManager::Base
        base.class_eval { extend ClassMethods }
      end

      extend ClassMethods
      
    end
  end
end