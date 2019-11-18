# frozen_string_literal: true

module LightweightSerializer
  class Serializer
    attr_reader :object, :options

    def self.inherited(base)
      base.defined_attributes = defined_attributes.deep_dup || {}
      base.defined_collection_serializers = defined_collection_serializers.deep_dup || {}
      base.defined_nested_serializers = defined_nested_serializers.deep_dup || {}
      super
    end

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

      attr_reader :defined_attributes, :defined_collection_serializers, :defined_nested_serializers, :skip_root_node

      protected
      attr_writer :defined_attributes, :defined_collection_serializers, :defined_nested_serializers
    end

    def initialize(object, **options)
      @object = object
      @options = options
    end

    def as_json
      result = {}

      self.class.defined_attributes.each do |attr_name, attribute_config|
        result[attr_name] = block_or_attribute_from_object(attribute_config)
      end

      self.class.defined_nested_serializers.each do |attr_name, attribute_config|
        nested_object = block_or_attribute_from_object(attribute_config)
        result[attr_name] = if nested_object.nil?
                              nil
                            else
                              attribute_config.serializer.new(nested_object, skip_root: true).as_json
                            end
      end

      self.class.defined_collection_serializers.each do |attr_name, attribute_config|
        nested_collection = block_or_attribute_from_object(attribute_config)

        result[attr_name] = Array(nested_collection).map do |collection_item|
          attribute_config.serializer.new(collection_item, skip_root: true).as_json
        end
      end

      if self.class.skip_root_node || options[:skip_root]
        result
      else
        { data: result }
      end
    end

    def to_json(*_args)
      Oj.dump(as_json, mode: :compat)
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
