# frozen_string_literal: true

module Grape
  class Entity
    class Preloader
      module Options # rubocop:disable Style/Documentation
        extend ActiveSupport::Concern

        prepended do
          def_delegators :opts_hash, :delete, :[]=
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
