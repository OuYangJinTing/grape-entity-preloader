# frozen_string_literal: true

module Grape
  class Entity
    class Preloader
      module Exposure
        module Base # rubocop:disable Style/Documentation
          extend ActiveSupport::Concern

          attr_reader :preload

          def initialize(_attribute, options, _conditions)
            @preload = options[:preload]
            raise ArgumentError, 'The :preload option must be a Symbol.' if @preload && !@preload.is_a?(Symbol)

            super
          end
        end
      end
    end
  end
end

Grape::Entity::Exposure::Base.include(Grape::Entity::Preloader::Exposure::Base)
