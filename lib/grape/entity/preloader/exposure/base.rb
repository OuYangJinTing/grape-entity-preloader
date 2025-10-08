# frozen_string_literal: true

module Grape
  class Entity
    class Preloader
      module Exposure
        module Base # rubocop:disable Style/Documentation
          extend ActiveSupport::Concern

          attr_reader :preload_association, :preload_callback, :preload_condition

          def initialize(_attribute, options, _conditions)
            @preload_association = options[:preload_association]
            @preload_callback = options[:preload_callback]
            @preload_condition = options[:preload_condition]
            validate_preload_options

            super
          end

          private

          def validate_preload_options # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
            if preload_association && !preload_association.is_a?(Symbol)
              raise ArgumentError, 'The :preload_association option must be a Symbol.'
            end

            if preload_callback && (!preload_callback.is_a?(Proc) || preload_callback.arity != 2)
              raise ArgumentError, 'The :preload_callback option must be a Proc with 2 arguments.'
            end

            if preload_condition && (!preload_condition.is_a?(Proc) || preload_condition.arity != 1)
              raise ArgumentError, 'The :preload_condition option must be a Proc with 1 argument.'
            end

            return unless preload_association && preload_callback

            raise ArgumentError, 'The :preload_association and :preload_callback options cannot be used together.'
          end
        end
      end
    end
  end
end

Grape::Entity::Exposure::Base.prepend(Grape::Entity::Preloader::Exposure::Base)
