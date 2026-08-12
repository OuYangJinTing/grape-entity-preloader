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
            validate_preload_option!

            super
          end

          def preload_association
            case preload
            when Symbol
              preload
            when Array
              value = preload[0]
              value.is_a?(Symbol) ? value : nil
            end
          end

          def preload_callback
            case preload
            when Proc
              preload
            when Array
              value = preload[0]
              value.is_a?(Proc) ? value : nil
            end
          end

          def preload_condition
            preload.last if preload.is_a?(Array)
          end

          private

          def validate_preload_option! # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/AbcSize,Metrics/PerceivedComplexity
            normalized_preload = Array.wrap(preload)
            return if normalized_preload.empty?
            raise ArgumentError if normalized_preload.size > 2

            first_value, second_value = normalized_preload
            raise ArgumentError if !first_value.is_a?(Symbol) && !first_value.is_a?(Proc)
            raise ArgumentError if first_value.is_a?(Proc) && first_value.arity != 2
            raise ArgumentError if second_value.is_a?(Proc) && second_value.arity != 1
          rescue ArgumentError
            raise ArgumentError, <<~MSG.strip_heredoc
              The :preload option must be a Symbol, Proc, or Array.
              - Symbol: :activerecord_association_name
              - Proc(callback): ->(objects, options) { { object1 => value1, object2 => value2 } }
                objects: An array of the parent objects being represented.
                options: The Grape::Entity::Options object for the current representation context.
                return: A Hash mapping each object to its preloaded value.
              - Array: [activerecord_association_name, condition_proc] | [callback_proc, condition_proc]
                condition_proc: ->(options) { ... }
                  options: The Grape::Entity::Options object for the root representation context.
                  return: A truthy or falsy value indicating whether preloading should be performed.

              eg:
                preload: :books
                preload: ->(objects, options) { ... }
                preload: [:books, ->(options) { ... }]
                preload: [->(objects, options) { ... }, ->(options) { ... }]
            MSG
          end
        end
      end
    end
  end
end

Grape::Entity::Exposure::Base.prepend(Grape::Entity::Preloader::Exposure::Base)
