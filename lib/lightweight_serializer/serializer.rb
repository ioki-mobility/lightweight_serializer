# frozen_string_literal: true

module LightweightSerializer
  class Serializer
    attr_reader :object

    class<<self
      def attribute(name, &blk)
        defined_attributes[name.to_sym] = Attribute.new(attr_name: name, block: blk)
      end

      def attributes(*names)
        names.each do |name|
          defined_attributes[name.to_sym] = Attribute.new(attr_name: name, block: nil)
        end
      end

      def nested(name, serializer:, &blk)
        defined_nested_serializers[name.to_sym] = NestedResource.new(attr_name: name, block: blk, serializer: serializer)
      end

      def collection(name, serializer:, &blk)
        defined_collection_serializers[name.to_sym] = NestedCollection.new(attr_name: name, block: blk, serializer: serializer)
      end

      def no_root!
        @skip_root_node = true
      end

      def defined_attributes
        @defined_attributes ||= {}
      end

      def defined_collection_serializers
        @defined_collection_serializers ||= {}
      end

      def defined_nested_serializers
        @defined_nested_serializers ||= {}
      end

      attr_reader :skip_root_node
    end

    def initialize(object)
      @object = object
    end

    def as_json
      {}.tap do |result|
        self.class.defined_attributes.each do |attr_name, attribute_config|
          result[attr_name] = block_or_attribute_from_object(attribute_config)
        end

        self.class.defined_nested_serializers.each do |attr_name, attribute_config|
          nested_object = block_or_attribute_from_object(attribute_config)
          result[attr_name] = if nested_object.nil?
                                nil
                              else
                                attribute_config.serializer.new(nested_object).as_json
                              end
        end

        self.class.defined_collection_serializers.each do |attr_name, attribute_config|
          nested_collection = block_or_attribute_from_object(attribute_config)

          result[attr_name] = Array(nested_collection).map do |collection_item|
            attribute_config.serializer.new(collection_item).as_json
          end
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

    private

    def block_or_attribute_from_object(attribute_config)
      if attribute_config.block
        instance_exec(object, &attribute_config.block)
      else
        object.public_send(attribute_config.attr_name)
      end
    end
  end

end
