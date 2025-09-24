# frozen_string_literal: true

if defined?(Grape::Endpoint)
  module Grape
    class Entity
      class Preloader
        module Endpoint # rubocop:disable Style/Documentation
          extend ActiveSupport::Concern

          def entity_representation_for(entity_class, object, options)
            return unless options[:enable_preloader]

            Preloader.new(entity_class, object, options).call
            super
          end
        end
      end
    end
  end

  Grape::Endpoint.include(Grape::Entity::Preloader::Endpoint)
end
