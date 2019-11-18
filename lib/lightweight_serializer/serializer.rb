# frozen_string_literal: true

module LightweightSerializer
  class Serializer
    attr_reader :object

    def initialize(object)
      @object = object
    end

    def as_json
      {}.tap do |result|
        self.class.defined_attributes.each do |attr_name, block|
          value = if block.nil?
                    object.public_send(attr_name)
                  else
                    block.call(object)
                  end

          result[attr_name] = value
        end
      end
    end

    def to_json(*_args)
      Oj.dump({ data: as_json }, mode: :compat)
    end

    class<<self
      def attribute(name, &blk)
        defined_attributes[name.to_sym] = blk
      end

      def attributes(*names)
        names.each do |name|
          defined_attributes[name.to_sym] = nil
        end
      end

      def defined_attributes
        @defined_attributes ||= {}
      end
    end
  end
end
