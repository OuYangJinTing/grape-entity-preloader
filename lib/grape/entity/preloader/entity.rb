# frozen_string_literal: true

module Grape
  class Entity
    class Preloader
      module Entity # rubocop:disable Style/Documentation
        extend ActiveSupport::Concern

        module ClassMethods # rubocop:disable Style/Documentation
          def preload_and_represent(objects, options = {})
            options = Options.new(options) unless options.is_a?(Options)
            Preloader.new(root_exposures, objects, options).call
            represent(objects, options)
          end
        end
      end
    end
  end
end

silence_warnings { Grape::Entity::OPTIONS = (Grape::Entity::OPTIONS + [:preload]).freeze }
Grape::Entity.include(Grape::Entity::Preloader::Entity)
