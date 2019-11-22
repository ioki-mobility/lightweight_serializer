# frozen_string_literal: true

module LightweightSerializer
  class Railtie < Rails::Railtie
    config.eager_load_namespaces << LightweightSerializer

    initializer 'lightweight_serializers.action_controller' do
      ActionController::Renderers.add :json do |object, options|
        if options[:serializer].blank? && !options[:no_serializer]
          raise ArgumentError,
                'You must provide a Serializer class to render JSON or use no_serializer: true option'
        end

        self.content_type = Mime[:json]

        serializer_class = options[:serializer]

        if options[:no_serializer]
          ActiveSupport::JSON.encode(object)
        else
          filtered_options = options.slice(*(serializer_class.allowed_options + [:skip_root, :meta]))
          serializer_class.new(object, filtered_options).to_json
        end
      end
    end
  end
end
