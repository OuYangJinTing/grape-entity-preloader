# frozen_string_literal: true

module Grape
  class Entity
    class Preloader
      module Exposure
        module Base # rubocop:disable Style/Documentation
          extend ActiveSupport::Concern

          attr_reader :preload_association, :preload_callback

          def initialize(_attribute, options, _conditions)
            @preload_association = options[:preload_association]
            @preload_callback = options[:preload_callback]

            if @preload_association && !@preload_association.is_a?(Symbol)
              raise ArgumentError, 'The :preload_association option must be a Symbol.'
            end

            if @preload_callback && !@preload_callback.is_a?(Proc)
              raise ArgumentError, 'The :preload_callback option must be a Proc.'
            end

            if @preload_association && @preload_callback
              raise ArgumentError, 'The :preload_association and :preload_callback options cannot be used together.'
            end

            super
          end
        end
      end
    end
  end
end

Grape::Entity::Exposure::Base.prepend(Grape::Entity::Preloader::Exposure::Base)
