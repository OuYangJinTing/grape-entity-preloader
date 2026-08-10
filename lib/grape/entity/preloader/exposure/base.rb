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
            validate_preload_option!(@preload)

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

          def validate_preload_option!(value) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/AbcSize,Metrics/PerceivedComplexity
            return if value.nil?

            first_value, second_value = Array.wrap(value)
            raise ArgumentError if !first_value.is_a?(Symbol) && !first_value.is_a?(Proc)
            raise ArgumentError if first_value.is_a?(Proc) && first_value.arity != 2
            raise ArgumentError if second_value.is_a?(Proc) && second_value.arity != 2
          rescue ArgumentError
            raise ArgumentError, <<~MSG.strip_heredoc
              The :preload option must be a Symbol, Proc, or Array.
              - Symbol: :activerecord_association_name
              - Proc: ->(objects, options) { ... }
                objects: An array of the parent objects being represented.
                options: The Grape::Entity::Options object for the current representation context.
              - Array: [activerecord_association_name, condition_proc] | [callback_proc, condition_proc]

              eg:
                preload: :books
                preload: ->(objects, options) { ... }
                preload: [:books, ->(objects, options) { ... }]
                preload: [->(objects, options) { ... }, ->(objects, options) { ... }]
            MSG
          end
        end
      end
    end
  end
end

Grape::Entity::Exposure::Base.prepend(Grape::Entity::Preloader::Exposure::Base)
