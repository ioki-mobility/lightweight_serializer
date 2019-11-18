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
      obj_to_dump = if self.class.skip_root_node
                      as_json
                    else
                      { data: as_json }
                    end

      Oj.dump(obj_to_dump, mode: :compat)
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

      def no_root!
        @skip_root_node = true
      end

      def defined_attributes
        @defined_attributes ||= {}
      end

      attr_reader :skip_root_node
    end
  end
end
