# frozen_string_literal: true

module Grape
  class Entity
    class Preloader
      module Entity # rubocop:disable Style/Documentation
        extend ActiveSupport::Concern

        module ClassMethods # rubocop:disable Style/Documentation
          def represent(objects, options = {})
            options = Options.new(options) unless options.is_a?(Options)
            Preloader.new(root_exposures, objects, options).call if options.delete(:enable_preloader)
            super(objects, options)
          end
        end
      end
    end
  end
end

Grape::Entity.include(Grape::Entity::Preloader::Entity)
silence_warnings { Grape::Entity::OPTIONS = (Grape::Entity::OPTIONS + %i[preload_association preload_callback]).freeze }
