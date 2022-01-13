# LightweightSerializer

LightweightSerializer is a gem that allows you to write serializers for your API, to define your JSON models. It is highly
opinionated, and tries to use as little magic as possible, but instead requires you to explicitly write what you want to
do.

As an addition, this gem also provides easy ways to generate [OpenAPI 3](https://swagger.io/specification/) compatible
specification for your API endpoints.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lightweight_serializer'
```

And then execute:

    $ bundle install

## Usage

To create a serializer, create a new file in your `app/serializers/` folder. Let's assume we have a nice blog:

```ruby
class PostSerializer < LightweightSerializer::Serializer
  attribute :title
  attribute :content

  collection :comments, serializer: CommentSerializer

  nested :author, serializer: UserSerializer
end

class CommentSerializer < LightweightSerializer::Serializer
  attribute :content
  attribute :name do |object|
    object.first_name + " " + object.last_name
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ioki-mobility/lightweight_serializer.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
