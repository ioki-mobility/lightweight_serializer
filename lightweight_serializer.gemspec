# frozen_string_literal: true

require_relative "lib/lightweight_serializer/version"

Gem::Specification.new do |spec|
  spec.name = "lightweight_serializer"
  spec.version = LightweightSerializer::VERSION
  spec.authors = ["Klaus Zanders"]
  spec.email = ["klaus.zanders@ioki.com"]

  spec.summary = "An easy DSL to write serializers for Rails applications, that can also generate OpenAPI 3.0 documentation"
  spec.description = <<~DESCRIPTION
  There will be more description here ;)
  DESCRIPTION
  spec.homepage = "https://github.com/ioki-mobility/lightweight_serializer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ioki-mobility/lightweight_serializer"
  spec.metadata["changelog_uri"] = "https://github.com/ioki-mobility/lightweight_serializer/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "railties", ">= 6.0"
  spec.add_dependency "activerecord", ">= 6.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
