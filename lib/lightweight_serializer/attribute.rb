# frozen_string_literal: true

module LightweightSerializer
  Attribute = Struct.new(
    :attr_name,
    :block,
    :condition,
    :group,
    :documentation,
    keyword_init: true
  )
end
