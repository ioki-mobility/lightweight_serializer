# frozen_string_literal: true

require 'set'
require 'active_record'
require 'active_model'

module LightweightSerializer
  class Serializer
    attr_reader :options

    def self.inherited(base)
      base.__lws_defined_attributes = __lws_defined_attributes.deep_dup || {}
      base.__lws_defined_nested_serializers = __lws_defined_nested_serializers.deep_dup || {}
      base.__lws_serialized_type = __lws_serialized_type.dup
      base.__lws_serialized_class = __lws_serialized_class.dup
      base.__lws_allowed_options = __lws_allowed_options.deep_dup || Set.new
      base.__lws_skip_automatic_type_field = !!__lws_skip_automatic_type_field
      super
    end

    class << self
      def allow_options(*option_names)
        self.__lws_allowed_options += option_names
      end

      def group(group_name, &blk)
        ensure_valid_name!(group_name)

        with_options(group: group_name, &blk)
      end

      def attribute(name, condition: nil, group: nil, **documentation_params, &blk)
        ensure_valid_name!(name)

        __lws_defined_attributes[name.to_sym] = Attribute.new(
          attr_name:     name,
          group:         group,
          condition:     condition,
          documentation: documentation_params,
          block:         blk
        )
        __lws_allowed_options << condition if condition.present?
      end

      def remove_attribute(name)
        __lws_defined_attributes.delete(name.to_sym)
        __lws_defined_nested_serializers.delete(name.to_sym)
      end

      def nested(name, serializer:, group: nil, condition: nil, **documentation_params, &blk)
        ensure_valid_name!(name)
        ensure_valid_serializers!(serializer)

        __lws_defined_nested_serializers[name.to_sym] = NestedResource.new(
          attr_name:     name,
          block:         blk,
          condition:     condition,
          serializer:    serializer,
          documentation: documentation_params,
          group:         group,
          array:         false
        )

        serializer_classes_from(serializer).each do |serializer_class|
          self.__lws_allowed_options += serializer_class.__lws_allowed_options
        end

        __lws_allowed_options << condition if condition.present?
      end

      def collection(name, serializer:, group: nil, condition: nil, **documentation_params, &blk)
        ensure_valid_name!(name)
        ensure_valid_serializers!(serializer)

        __lws_defined_nested_serializers[name.to_sym] = NestedResource.new(
          attr_name:     name,
          block:         blk,
          condition:     condition,
          serializer:    serializer,
          documentation: documentation_params,
          group:         group,
          array:         true
        )

        serializer_classes_from(serializer).each do |serializer_class|
          self.__lws_allowed_options += serializer_class.__lws_allowed_options
        end

        __lws_allowed_options << condition if condition.present?
      end

      def serializes(type: nil, model: nil)
        @__lws_serialized_type = type
        @__lws_serialized_class = model
      end

      def no_root!
        @__lws_skip_root_node = true
      end

      def no_automatic_type_field!
        @__lws_skip_automatic_type_field = true
      end

      attr_reader :__lws_defined_attributes,
                  :__lws_defined_nested_serializers,
                  :__lws_skip_root_node,
                  :__lws_skip_automatic_type_field,
                  :__lws_allowed_options,
                  :__lws_serialized_type,
                  :__lws_serialized_class

      protected

      attr_writer :__lws_defined_attributes,
                  :__lws_defined_nested_serializers,
                  :__lws_skip_automatic_type_field,
                  :__lws_allowed_options,
                  :__lws_serialized_type,
                  :__lws_serialized_class

      def serializer_classes_from(serializer_data)
        if serializer_data.is_a?(Hash)
          serializer_data.values
        else
          [serializer_data]
        end
      end

      private

      def ensure_valid_serializers!(serializer_data)
        return if serializer_data.is_a?(Hash) && serializer_data.values.all? do |serializer|
          serializer.ancestors.include?(LightweightSerializer::Serializer)
        end
        return if serializer_data.ancestors.include?(LightweightSerializer::Serializer)

        raise ArgumentError, <<~ERROR_MESSAGE
          The nested serializers must be defined as:
            - A class derived from LightweightSerializer::Serializer
            - A hash in the format:
                { ModelClass => SerializerClass, OtherModelClass => OtherSerializerClass }
        ERROR_MESSAGE
      end

      def ensure_valid_name!(attr_name)
        return if attr_name != :type
        return if __lws_skip_automatic_type_field

        raise ArgumentError, <<~ERROR_MESSAGE
          Cannot use "type" as a an attribute name with automatic type-field-generation.

          Either use a prefixed type name (like "user_type") or add "no_automatic_type_field!" to the definition.
        ERROR_MESSAGE
      end
    end

    def initialize(object_or_collection, **options)
      @object_or_collection = object_or_collection
      @options = options
    end

    def as_json(*_args)
      result = if @object_or_collection.nil?
                 nil
               elsif @object_or_collection.is_a?(Array) ||
                     @object_or_collection.is_a?(ActiveRecord::Relation) ||
                     @object_or_collection.is_a?(ActiveModel::Errors)
                 @object_or_collection.map do |object|
                   serialized_object(object).tap do |hash|
                     hash[:type] = type_data(object) unless self.class.__lws_skip_automatic_type_field
                   end
                 end
               else
                 serialized_object(@object_or_collection).tap do |hash|
                   hash[:type] = type_data(@object_or_collection) unless self.class.__lws_skip_automatic_type_field
                 end
               end

      if self.class.__lws_skip_root_node || options[:skip_root]
        result
      else
        { data: result }.tap do |final_hash|
          final_hash[:meta] = options[:meta] if options[:meta].present?
        end
      end
    end

    private

    def serialized_object(object)
      result = {}

      self.class.__lws_defined_attributes.each do |attr_name, attribute_config|
        next if attribute_config.condition && !options[attribute_config.condition]

        if attribute_config.group.present?
          result[attribute_config.group] ||= {}
          result[attribute_config.group][attr_name] = block_or_attribute_from_object(object, attribute_config)
        else
          result[attr_name] = block_or_attribute_from_object(object, attribute_config)
        end
      end

      self.class.__lws_defined_nested_serializers.each do |attr_name, attribute_config|
        next if attribute_config.condition && !options[attribute_config.condition]

        nested_object = block_or_attribute_from_object(object, attribute_config)
        value = if nested_object.nil?
                  nil
                elsif nested_object.is_a?(Array)
                  nested_object.map do |nested_element|
                    sub_options = options_for_nested_serializer(attribute_config)

                    serializer_class = serializer_for(
                      attribute_config.serializer,
                      nested_element.class
                    )

                    serializer_class.new(nested_element, **sub_options).as_json
                  end
                else
                  sub_options = options_for_nested_serializer(attribute_config)

                  serializer_class = serializer_for(
                    attribute_config.serializer,
                    nested_object.class
                  )

                  serializer_class.new(nested_object, **sub_options).as_json
                end

        if attribute_config.group.present?
          result[attribute_config.group] ||= {}
          result[attribute_config.group][attr_name] = value
        else
          result[attr_name] = value
        end
      end

      result
    end

    def serializer_for(serializer_data, model_class)
      if serializer_data.is_a?(Hash)
        if serializer_data.key?(model_class)
          serializer_data[model_class]
        elsif serializer_data.key?(:fallback)
          serializer_data[:fallback]
        else
          raise ArgumentError, "No Serializer defined for argument of type \"#{model_class}\"."
        end
      else
        serializer_data
      end
    end

    def serializer_classes(serializer_data)
      if serializer_data.is_a?(Hash)
        serializer_data.values
      else
        [serializer_data]
      end
    end

    def options_for_nested_serializer(attribute_config)
      allowed_options = serializer_classes(attribute_config.serializer)
        .map { |serializer| serializer.__lws_allowed_options.to_a }
        .flatten

      options
        .slice(*allowed_options)
        .merge(skip_root: true)
    end

    def block_or_attribute_from_object(object, attribute_config)
      if attribute_config.block
        instance_exec(object, &attribute_config.block)
      elsif object.is_a? Hash
        object.fetch(attribute_config.attr_name)
      else
        object.public_send(attribute_config.attr_name)
      end
    end

    def type_data(object)
      if self.class.__lws_serialized_type.present?
        self.class.__lws_serialized_type
      elsif self.class.__lws_serialized_class.present? && self.class.__lws_serialized_class.is_a?(Class)
        self.class.__lws_serialized_class.name.underscore
      elsif self.class.__lws_serialized_class.present? && self.class.__lws_serialized_class.is_a?(String)
        self.class.__lws_serialized_class.underscore
      else
        object.class.name.underscore
      end
    end
  end
end
