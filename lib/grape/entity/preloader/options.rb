# frozen_string_literal: true

module Grape
  class Entity
    class Preloader
      module Options # rubocop:disable Style/Documentation
        extend ActiveSupport::Concern

        prepended do
          def_delegators :opts_hash, :delete, :[]=
        end

        # Grape-Entity builds new Options objects via merge/reverse_merge (e.g.
        # reverse_merge(collection: true) when representing an array). The
        # default implementation copies opts_hash but drops @for_nesting_cache,
        # so nested Options created during preloading (and their populated
        # PRELOAD_CACHE_KEY caches) are lost before later serialization. Copy the
        # cache so the same nested Options are reused.
        def merge(...)
          super.tap { |options| options.instance_variable_set(:@for_nesting_cache, @for_nesting_cache.dup) }
        end
        def reverse_merge(...) # rubocop:disable Layout/EmptyLineBetweenDefs
          super.tap { |options| options.instance_variable_set(:@for_nesting_cache, @for_nesting_cache.dup) }
        end

        private

        def build_for_nesting(...)
          # Clear preload cache for nested entities to avoid sharing cache across nesting levels
          super.tap { |options| options.opts_hash[PRELOAD_CACHE_KEY] = {} }
        end
      end
    end
  end
end

Grape::Entity::Options.prepend(Grape::Entity::Preloader::Options)
