require 'yaml'
if YAML.parser.class.name =~ /syck|yecht/i
  module StateManager
    class Base
      yaml_as "tag:grouptalent.com,2012:StateManager"

      def self.yaml_new(klass, tag, val)
        klass.new(val['resource'], val['context'])
      end

      def to_yaml_properties
        ['@resource', '@context']
      end
    end
  end
else
  module StateManager
    class Base
      def encode_with(coder)
        coder.map = {
          "resource" => resource,
          "context" => context
        }
      end

      def init_with(coder)
        initialize(coder["resource"], coder["context"])
      end
    end
  end
end