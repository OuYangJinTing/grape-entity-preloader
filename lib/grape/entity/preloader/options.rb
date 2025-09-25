# frozen_string_literal: true

module Grape
  class Entity
    class Preloader
      module Options # rubocop:disable Style/Documentation
        extend ActiveSupport::Concern

        included do
          def_delegators :opts_hash, :delete
        end
      end
    end
  end
end

Grape::Entity::Options.include(Grape::Entity::Preloader::Options)
