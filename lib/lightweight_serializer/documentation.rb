# frozen_string_literal: true

module LightweightSerializer
  class Documentation
    attr_reader :serializer

    ALLOWED_SCHEMA_ATTRIBUTES = [
      :title,
      :multipleOf,
      :maximum,
      :exclusiveMaximum,
      :minimum,
      :exclusiveMinimum,
      :maxLength,
      :minLength,
      :pattern,
      :maxItems,
      :minItems,
      :uniqueItems,
      :maxProperties,
      :minProperties,
      :required,
      :enum,
      :type,
      :allOf,
      :oneOf,
      :anyOf,
      :not,
      :items,
      :properties,
      :additionalProperties,
      :description,
      :format,
      :default,
      :nullable,
      :readOnly,
      :writeOnly,
      :xml,
      :externalDocs,
      :example,
      :deprecated
    ].freeze

    def initialize(serializer_class)
      @serializer = serializer_class
    end

    def self.identifier_for(serializer)
      serializer.name.gsub(/Serializer/, '').underscore.gsub('/', '--')
    end

    def identifier
      self.class.identifier_for(serializer)
    end

    def openapi_schema
      result = {
        type:       'object',
        properties: base_properties_hash
      }

      defintions = attribute_definitions + nested_definitions

      defintions.each do |(attr_name, group, documentation)|
        if group
          result[:properties][group] ||= { type: 'object', properties: {} }
          result[:properties][group][:properties][attr_name] = documentation
        else
          result[:properties][attr_name] = documentation
        end
      end

      result
    end

    private

    def base_properties_hash
      return {} if serializer.__lws_skip_automatic_type_field

      if type_data.present?
        {
          type: {
            type:        :string,
            description: 'A string identifying the type of the serialized object',
            enum:        [type_data],
            example:     type_data
          }
        }
      else
        {
          type: {
            type:        :string,
            description: 'A string identifying the type of the serialized object'
          }
        }
      end
    end

    def type_data
      if serializer.__lws_serialized_type.present?
        serializer.__lws_serialized_type
      elsif serializer.__lws_serialized_class.present? && serializer.__lws_serialized_class.is_a?(Class)
        serializer.__lws_serialized_class.name.underscore
      elsif serializer.__lws_serialized_class.present? && serializer.__lws_serialized_class.is_a?(String)
        serializer.__lws_serialized_class.underscore
      else
        nil
      end
    end

    def attribute_definitions
      serializer.__lws_defined_attributes.map do |attr_name, config|
        [attr_name, config.group, sanitized_documentation_hash(config.documentation)]
      end
    end

    def nested_definitions
      serializer.__lws_defined_nested_serializers.map do |attr_name, config|
        documentation = sanitized_documentation_hash(config.documentation)

        if config.array
          documentation[:type] = :array
          documentation[:items] = { '$ref': "#/components/schemas/#{self.class.identifier_for(config[:serializer])}" }
        elsif documentation[:nullable]
          documentation[:oneOf] = [
            { type: :null },
            { '$ref': "#/components/schemas/#{self.class.identifier_for(config[:serializer])}" }
          ]
        else
          documentation[:allOf] = [
            { '$ref': "#/components/schemas/#{self.class.identifier_for(config[:serializer])}" }
          ]
        end

        [attr_name, config.group, documentation]
      end
    end

    def sanitized_documentation_hash(hash)
      hash.slice(*ALLOWED_SCHEMA_ATTRIBUTES)
    end
  end
end
