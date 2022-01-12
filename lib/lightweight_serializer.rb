# frozen_string_literal: true

require_relative "lightweight_serializer/version"

module LightweightSerializer
  require_relative 'lightweight_serializer/attribute'
  require_relative 'lightweight_serializer/nested_resource'

  require_relative 'lightweight_serializer/serializer'
  require_relative 'lightweight_serializer/documentation'
  require_relative 'lightweight_serializer/railtie'
end
