# frozen_string_literal: true

require 'grape-entity'
require_relative 'preloader/version'
require_relative 'preloader/entity'
require_relative 'preloader/options'
require_relative 'preloader/exposure/base'

module Grape
  class Entity
    class Preloader # rubocop:disable Style/Documentation
      attr_reader :exposures, :objects, :options, :associations, :callbacks, :nested_association_chain

      def self.activerecord_gte_7_0?
        unless defined?(ActiveRecord) && ActiveRecord.respond_to?(:version) && ActiveRecord.version >= Gem::Version.new('7.0')
          warn 'ActiveRecord 7.0 or later is required for preload association'
          return false
        end

        true
      end

      def initialize(exposures, objects, options)
        @exposures = exposures
        @objects = Array.wrap(objects)
        @options = options

        @associations = {}
        @callbacks = Hash.new { |hash, key| hash[key] = [] }
        @nested_association_chain = []
      end

      def call
        return if objects.empty?

        extract_preload_options(exposures, options, associations)
        execute_preload_associations
        execute_preload_callbacks
      end

      private

      def execute_preload_associations
        return unless Preloader.activerecord_gte_7_0?

        # TODO: Change ActiveRecord async query
        ActiveRecord::Associations::Preloader.new(records: objects, associations: associations).call
      end

      def execute_preload_callbacks # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        callbacks.each do |association_chain, exposures_with_options|
          association_objects = association_chain.inject(objects) do |items, association|
            items.filter_map(&association).flatten(1)
          end
          next if association_objects.empty?

          exposures_with_options.each do |exposure, options|
            callback_objects = exposure.preload_callback.call(association_objects, options)
            if exposure.is_a?(Grape::Entity::Exposure::RepresentExposure)
              Preloader.new(exposure.using_class.root_exposures, callback_objects, options).call
            end
          end
        end
      end

      def extract_preload_options(exposures, options, associations) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
        exposures.each do |exposure|
          next unless exposure.should_return_key?(options)
          next if exposure.preload_condition && !exposure.preload_condition.call(options)

          if exposure.preload_callback
            callbacks[nested_association_chain.dup] << [exposure, options]
          elsif exposure.preload_association && Preloader.activerecord_gte_7_0?
            associations[exposure.preload_association] ||= {}
          end

          key_of_exposure = exposure.instance_variable_get(:@key)
          # Dynamic keys are difficult to handle and less used, skipped directly
          next if key_of_exposure.respond_to?(:call)

          if exposure.is_a?(Grape::Entity::Exposure::NestingExposure)
            extract_preload_options(
              exposure.nested_exposures,
              options.for_nesting(key_of_exposure),
              associations
            )
          elsif exposure.is_a?(Grape::Entity::Exposure::RepresentExposure) && associations[exposure.preload_association]
            nested_association_chain.push(exposure.preload_association)
            extract_preload_options(
              exposure.using_class.root_exposures,
              options.for_nesting(key_of_exposure),
              associations[exposure.preload_association]
            )
            nested_association_chain.pop
          end
        end
      end
    end
  end
end
