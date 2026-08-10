# Grape::Entity::Preloader

[![Ruby](https://github.com/OuYangJinTing/grape-entity-preloader/actions/workflows/main.yml/badge.svg)](https://github.com/OuYangJinTing/grape-entity-preloader/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/grape-entity-preloader.svg?icon=si%3Arubygems&icon_color=%23ff0000)](https://badge.fury.io/rb/grape-entity-preloader)

Grape::Entity::Preloader allows preload associations and callbacks for avoiding N+1 operations in Grape::Entity.

## Installation

```bash
bundle add grape-entity-preloader
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install grape-entity-preloader
```

## Usage

### Activation

#### Global Activation

You can enable the preloader globally. This is useful in environments where you want preloading to be the default behavior.

```ruby
# config/initializers/grape_entity_preloader.rb
Grape::Entity::Preloader.enabled!
```

#### Local Activation and Deactivation

You can control preloading for specific `represent` calls.
For a specific block of code, you can use `with_enable` or `with_disable`. This is useful in contexts like API endpoints or middlewares.

```ruby
Grape::Entity::Preloader.with_enable do
  # Preloading is enabled for all represent calls inside this block
  MyAPI::Entities::User.represent(User.all)
end

Grape::Entity::Preloader.with_disable do
  # Preloading is disabled for all represent calls inside this block
  MyAPI::Entities::User.represent(User.all)
end
```

### `preload`

Use `preload` to configure preloading for an exposure. It can be a `Symbol` to preload an ActiveRecord association, a `Proc` to run a custom preload callback, or an `Array` with an optional condition.

#### Association preloading

A `Symbol` value preloads the named association:

```ruby
class UserEntity < Grape::Entity
  expose :id
  expose :name
  # This will preload the `books` association for all users being represented.
  expose :books, using: BookEntity, preload: :books
end

# In your API
users = User.limit(10)
# When UserEntity represents users, it will execute two queries:
# 1. SELECT * FROM users LIMIT 10
# 2. SELECT * FROM books WHERE books.user_id IN (...)
UserEntity.represent(users)
```

For nested preloading:

```ruby
class BookEntity < Grape::Entity
  expose :id
  expose :title
  # This will preload tags for each book
  expose :tags, using: TagEntity, preload: :tags
end

class UserEntity < Grape::Entity
  expose :id
  expose :name
  expose :books, using: BookEntity, preload: :books
end

# It will generate 3 queries instead of 1 + 10 (for books) + N (for tags)
UserEntity.represent(User.limit(10))
```

#### Custom preloading callback

For more complex scenarios that association preloading doesn't cover (e.g., loading data from other services, custom caching logic), you can use a `Proc` that accepts two arguments:

1. `objects`: An array of the parent objects being represented.
2. `options`: The `Grape::Entity::Options` object for the current representation context.

This is the same `objects` / `options` signature used by conditional preloading (see below).

**The `Proc` should return an array of objects that will be used for the nested entity representation. These returned objects will then be passed to the preloader for that nested entity, allowing for further nested preloading.**

```ruby
class UserStatsEntity < Grape::Entity
  expose :likes
  expose :followers
end

class UserEntity < Grape::Entity
  expose :id
  expose :name

  expose :stats, using: UserStatsEntity, preload: ->(users, _options) do
    # `users` is an array of User objects.
    # Here you can fetch stats for all users in one batch.
    user_ids = users.map(&:id)
    stats_data = StatsService.batch_get_by_user_ids(user_ids) # returns a hash { user_id => stats_object }

    # The preloader needs to associate the loaded data back to the original objects.
    # A common pattern is to attach the data to a new attribute on the object.
    users.each { |user| user.instance_variable_set(:@stats, stats_data[user.id]) }

    # The block must return the objects that will be presented by the nested entity.
    # In this case, it's the stats objects we just loaded.
    users.map { |user| user.instance_variable_get(:@stats) }
  end do |user, _options|
    user.instance_variable_get(:@stats)
  end
end
```

#### Conditional preloading

When you need a condition, pass an `Array` where the first element is the preload value and the second element is a `Proc` that accepts two arguments: `objects` and `options`. The condition `Proc` receives the same arguments as a custom preload callback `Proc`.

If the condition `Proc` returns a falsy value, preloading for that exposure will be skipped.

```ruby
class UserEntity < Grape::Entity
  expose :id
  expose :name

  # The :audit_log association will only be preloaded if `include_audit_log` is true in the options.
  expose :audit_log,
         using: AuditLogEntity,
         preload: [:audit_log, ->(_objects, options) { options[:include_audit_log] }]
end

# Preloading for :audit_log is skipped
UserEntity.represent(user)

# Preloading for :audit_log is executed
UserEntity.represent(user, include_audit_log: true)
```

For a callback with a condition:

```ruby
class UserEntity < Grape::Entity
  expose :stats,
         using: UserStatsEntity,
         preload: [
           ->(users, _options) { StatsService.batch_get(users) },
           ->(_objects, options) { options[:include_stats] }
         ]
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/OuYangJinTing/grape-entity-preloader. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/OuYangJinTing/grape-entity-preloader/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Grape::Entity::Preloader project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/OuYangJinTing/grape-entity-preloader/blob/master/CODE_OF_CONDUCT.md).
