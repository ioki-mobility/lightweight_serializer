# LightweightSerializer [![CI Status](https://github.com/ioki-mobility/lightweight_serializer/actions/workflows/main.yml/badge.svg)](https://github.com/ioki-mobility/lightweight_serializer/actions/workflows/main.yml)

LightweightSerializer is a gem that allows you to write serializers for your API, to define your JSON models. It is highly opinionated, and tries to use as little magic as possible, but instead requires you to explicitly write what you want to do.

As an addition, this gem also provides easy ways to generate an [OpenAPI 3](https://swagger.io/specification/) compatible specification for your API endpoints.

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'lightweight_serializer'
```

And then execute:

    $ bundle install

## Usage

Let us assume a blog data structure. Given the following serializers:

```ruby
class CommentSerializer < LightweightSerializer::Serializer
  attribute :content
  attribute :name do |object|
    object.first_name + " " + object.last_name
  end
end

class UserSerializer < LightweightSerializer::Serializer
  attribute :email
  attribute :name
end

class PostSerializer < LightweightSerializer::Serializer
  attribute :title
  attribute :content

  collection :comments, serializer: CommentSerializer

  nested :author, serializer: UserSerializer
end
```

Serialize it with:

```ruby
post = {title: 'Using LightweightSerializer', content: 'Lorem ipsum', comments: [OpenStruct.new({content: 'Great post!', first_name: 'Sarah', last_name: 'Muster'})], author: {email: 'muster@example.com', name: 'Dominik Muster'}}

serializer = PostSerializer.new(post)
serializer.as_json
```

This outputs a Ruby `Hash`:

```ruby
{
  data: {
    title: "Using LightweightSerializer",
    content: "Lorem ipsum",
    comments: [
      {
        content: "Great post!",
        name: "Sarah Muster",
        type: "open_struct"
      }
    ],
    author: {
      email: "muster@example.com",
      name: "Dominik Muster",
      type: "hash"
    },
    type: "hash"
  }
}
```

You can pass any object or a hash to the serializer.

### Serializer DSL

The following DSL can be used within a `LightweightSerializer::Serializer`.

#### `attribute`

Serialize an attribute (same name in the output as in the object):

```ruby
attribute :name
```

Serialize an attribute with a different name (outputs `name`, but reads `full_name` from the object):

```ruby
attribute :name, &:full_name
```

Note that this is the same as the following. By passing a block, it is possible to include further logic to conclude on the serialized value. The passed `object` in the block is the same as the one the serializer was called with.

```ruby
attribute(:name) { |object| object.full_name }
```

Do not forget the parantheses around the attribute name when specifying a block.

This is also required for boolean methods conventionally ending with a `?`:

```ruby
attribute :admin, &:admin?
```

Conditionally include specific attributes:

```ruby
class PostSerializer < LightweightSerializer::Serializer
  attribute :title # Serialized in any case
  attribute :state, condition: :admin # Serialized only if `admin` is truthy
end

PostSerializer.new(post, admin: current_user.admin?)
```

Move the attribute to a group:

```ruby
attribute :name, group: :author
```

`Serializer.new({name: 'Sarah'}).as_json` outputs:

```ruby
{
  data: {
    author: {
      name: "Sarah"
    }
  }
}
```

Note that it may be more readable to use `group` directly instead:

```ruby
group :author do
  attribute :name
end
```

#### `nested`

Nest another object:

```ruby
nested :author, serializer: AuthorSerializer
```

The output would be:

```ruby
{
  author: {
    ...
  }
}
```

`nested` also supports the `group` and `condition` options (cf. `attribute`).

#### `collection`

Serializes an array of a resource:

```ruby
collection :comments, serializer: CommentSerializer
```

The output would be:

```ruby
{
  comments: [
    {
      # first comment
    },
    {
      # second comment
    }
  ]
}
```

`collection` also supports the `group` and `condition` options (cf. `attribute`).

When you are intending to pass multiple objects into a subserializer, you can specify a hash in the format
`{ Class => SerializerClass }` as the `serializer` parameter. For every object that is given to the serializer, the
correct serializer class is looked up. Note, that this only checks for the exact class, you cannot use a base class
as the key and expect every subclass to be matched.

If you pass in an object of a type, that is not included in the list, an `ArgumentError` will be raised.

If you intend to have soms sort of generic fallback serializer, that all unmatched objects should be serialized with,
you can specify a `:fallback` option.

```ruby
TechPost = Struct.new(:title, :technology)
SciencePost = Struct.new(:title, :field)
Post = Struct.new(:title)

class GenericPostSerializer < LightweightSerializer::Serializer
  attribute :title
end

class TechPostSerializer < LightweightSerializer::Serializer
  attribute :title
  attribute :technology
end

class SciencePostSerializer < LightweightSerializer::Serializer
  attribute :title
  attribute :field
end

class BlogSerializer < LightweightSerializer::Serializer
  collection :posts, serializer: {
    TechPost => TechPostSerializer,
    SciencePost => SciencePostSerial,
    fallback: GenericPostSerializer
  }
end

BlogSerializer.new({posts: [
  TechPost.new('Lorem', 'JS'),
  SciencePost.new('Ipsum', 'SE'),
  Post.new("Dolor")
]}).as_json

# {
#   data: {
#     posts: [
#       { title: "Lorem", technology: "JS", type: "tech_post" },
#       { title: "Ipsum", field: "SE", type: "science_post" },
#       { title: "Dolor" }
#     ],
#     type: "hash"
#   }
# }
```

#### `no_automatic_type_field!`

```ruby
class PostSerializer < LightweightSerializer::Serializer
  no_automatic_type_field!
  attribute :title
end
```

Does not write the `type` attribute. The above would output:

```ruby
{
  data: {
    title: '..'
  }
}
```

As opposed to the following if omitting `no_automatic_type_field!`:

```ruby
{
  data: {
    title: '..',
    type: 'post'
  }
}
```

#### `no_root!`

```ruby
class PostSerializer < LightweightSerializer::Serializer
  no_root!
  attribute :title
end
```

Does not write the outer `data` attribute. The above would output:

```ruby
{
  title: '..',
  type: 'post'
}
```

As opposed to the following if omitting `no_root!`:

```ruby
{
  data: {
    title: '..',
    type: 'post'
  }
}
```

#### `group`

Groups one or more attributes in the output nested into the given name:

```ruby
group :author do
  attribute :first_name
  attribute :last_name
end
```

This outputs:

```ruby
{
  data: {
    author: {
      first_name: "Sarah",
      last_name: "Muster"
    },
    type: "hash"
  }
}
```

#### `remove_attribute`

Removes an attribute from the serializer. This is useful when inheriting from a serializer, but not all attributes should be serialized.

```ruby
class PersonSerializer < LightweightSerializer::Serializer
  attribute :name
  attribute :city
end

class AuthorSerializer < PersonSerializer
  remove_attribute :city
end

AuthorSerializer.new({name: 'Sarah Muster', city: 'Musterhausen'}).as_json
# {
#   data: {
#     name: "Sarah Muster",
#     type: "hash"
#   }
# }

PersonSerializer.new({name: 'Sarah Muster', city: 'Musterhausen'}).as_json
# {
#   data: {
#     name: "Sarah Muster",
#     city: "Musterhausen",
#     type: "hash"
#   }
# }
```

#### `serializes`

Defines the type being serialized. This is mostly useful when serializing hashes or an `OpenStruct`, as these would otherwise be serialized as `type: "hash"` and `type: "open_struct"`.

```ruby
serializes type:, model:
```

`type` should be a symbol or a string and is used exactly as given. It always has precedence over `model`. `model` can be either a `Class` or a string, but `underscore` is called on it.

Example for `type`:

```ruby
class PostSerializer < LightweightSerializer::Serializer
  serializes type: 'Post'
  attribute :title
end

PostSerializer.new({title: 'Lorem'}).as_json
# {
#   data: {
#     title: "Lorem",
#     type: "Post"
#   }
# }
```

Example for `model` with a `Class`:

```ruby
class Post
end

class PostSerializer < LightweightSerializer::Serializer
  serializes model: Post
  attribute :title
end

PostSerializer.new({title: 'Lorem'}).as_json
# {
#   data: {
#     title: "Lorem",
#     type: "post"
#   }
# }
```

Example for `model` with a string:

```ruby
class BlogPostSerializer < LightweightSerializer::Serializer
  serializes model: 'BlogPost'
  attribute :title
end

BlogPostSerializer.new({title: 'Lorem'}).as_json
# {
#   data: {
#     title: "Lorem",
#     type: "blog_post"
#   }
# }
```

### Options to serializers

Use `skip_root` to avoid `data` to be added:

```ruby
PostSerializer.new({title: 'Lorem'}, skip_root: true).as_json
```

This outputs:

```ruby
{title: "Lorem", type: "hash"}
```

This has the same effect as adding `no_root!` to the serializer. Note that `no_root!` has always precedence. You cannot readd `data` by specifying `skip_root: false`.

If the `data` attribute is included in the output, you can use `meta` to add any additional information alongside. It is most often used for pagination information, but the content of `meta` is arbitrary.

```ruby
PostSerializer.new([{title: 'Lorem'}], meta: {page: 1, total: 10}).as_json
```

Outputs:

```ruby
{
  data: [
    {title: "Lorem", type: "hash"}
  ],
  meta: {
    page: 1, total: 10
  }
}
```

Note that `meta` is ignored when the serializer uses `no_root!`.

It is possible to pass additional options to the serializer, which can then be used within it by accessing `options`:

```ruby
class PostSerializer < LightweightSerializer::Serializer
  allow_options :current_user

  attribute :author do
    options[:current_user].email
  end
end

current_user = OpenStruct.new(email: "sarah@example.com")

puts PostSerializer.new({}, current_user: current_user).to_json
# => {"data":{"author":"sarah@example.com","type":"hash"}}
```

### Documentation

Use the following to generate the OpenAPI specification for an object represented by a serializer:

```ruby
LightweightSerializer::Documentation.new(PostSerializer).openapi_schema
```

To get any meaningful output, document the attributes in your serializers with the following additional options. Make sure that you put the documentation options after all serializer options.

```
additionalProperties
allOf
anyOf
default
deprecated
description
enum
example
exclusiveMaximum
exclusiveMinimum
externalDocs
format
items
maximum
maxItems
maxLength
maxProperties
minimum
minItems
minLength
minProperties
multipleOf
not
nullable
oneOf
pattern
properties
readOnly
required
title
type
uniqueItems
writeOnly
xml
```

Refer to the [OpenAPI specification](https://spec.openapis.org/oas/latest.html) to learn about the accepted values of these options.

### Rails

-   Put your serializers in `app/serializers/`.
-   Add an `ApplicationSerializer` to share common options:

    ```ruby
    class ApplicationSerializer < LightweightSerializer::Serializer
      no_automatic_type_field!
    end
    ```

    Then inherit from it:

    ```ruby
    class PostSerializer < ApplicationSerializer
    end
    ```

-   In a controller action, render JSON as follows:

    ```ruby
    render json: objects, serializer: PostSerializer`
    ```

    If you want to serialize without a serializer:

    ```ruby
    render json: objects, no_serializer: true
    ```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ioki-mobility/lightweight_serializer.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
