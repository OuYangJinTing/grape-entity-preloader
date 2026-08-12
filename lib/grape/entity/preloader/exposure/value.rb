# frozen_string_literal: true

module Grape
  class Entity
    class Preloader
      module Exposure
        module Value # rubocop:disable Style/Documentation
          def value(entity, options)
            cache = options.dig(PRELOAD_CACHE_KEY, preload_callback)
            cache.is_a?(Hash) ? cache[entity.object] : super
          end

          # Always return true for preloaded exposures since they are always valid
          # The actual validation happens in the #value method
          def valid?(entity)
            preload_callback ? true : super
          end
        end
      end
    end
  end
end

Grape::Entity::Exposure::DelegatorExposure.prepend(Grape::Entity::Preloader::Exposure::Value)
Grape::Entity::Exposure::BlockExposure.prepend(Grape::Entity::Preloader::Exposure::Value)
Grape::Entity::Exposure::FormatterExposure.prepend(Grape::Entity::Preloader::Exposure::Value)
Grape::Entity::Exposure::FormatterBlockExposure.prepend(Grape::Entity::Preloader::Exposure::Value)
