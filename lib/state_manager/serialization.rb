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