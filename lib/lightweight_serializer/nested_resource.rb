# frozen_string_literal: true

module LightweightSerializer
  NestedResource = Struct.new(
    :attr_name,
    :block,
    :serializer,
    :group,
    :condition,
    :array,
    :documentation,
    keyword_init: true
  )
end
