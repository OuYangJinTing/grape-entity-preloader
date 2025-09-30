# frozen_string_literal: true

require 'grape-entity'
require_relative 'preloader/version'
require_relative 'preloader/entity'
require_relative 'preloader/options'
require_relative 'preloader/exposure/base'

module Grape
  class Entity
    class Preloader # rubocop:disable Style/Documentation
      attr_reader :exposures, :objects, :options

      def self.activerecord_gte_7_0?
        unless defined?(ActiveRecord) && ActiveRecord.respond_to?(:version) && ActiveRecord.version >= Gem::Version.new('7.0')
          warn 'ActiveRecord 7.0 or later is required for preload association'
        end

        true
      end

      def initialize(exposures, objects, options)
        @exposures = exposures
        @objects = Array.wrap(objects)
        @options = options
      end

      def call
        associations = {}
        exposures_with_callbacks = {}
        extract_preload_options(exposures, options, associations, exposures_with_callbacks)
        preload_associations(objects, associations)
        preload_callbacks(objects, exposures_with_callbacks)
      end

      private

      def preload_associations(objects, associations)
        return unless Preloader.activerecord_gte_7_0?

        # TODO: Change ActiveRecord async query
        ActiveRecord::Associations::Preloader.new(records: objects, associations: associations).call
      end

      def preload_callbacks(objects, exposures_with_callbacks)
        exposures_with_callbacks.each do |association_chain, (exposure, options)|
          association_objects = objects
          association_chain.each do |association|
            association_objects = association_objects.flat_map { |object| object.send(association) }
          end
          callback_objects = exposure.preload_callback.call(association_objects)

          if exposure.is_a?(Grape::Entity::Exposure::RepresentExposure)
            Preloader.new(exposure.using_class.root_exposures, callback_objects, options).call
          end
        end
      end

      def extract_preload_options(exposures, options, associations, exposures_with_callbacks)
        association_chain = association_chain(associations)

        exposures.each do |exposure|
          next unless exposure.should_return_key?(options)

          if exposure.preload_callback
            exposures_with_callbacks[association_chain] = [exposure, options]
          elsif exposure.preload_association && Preloader.activerecord_gte_7_0?
            associations[exposure.preload_association] ||= {}
          end

          deep_extract_preload_options(exposure, options, associations, exposures_with_callbacks)
        end
      end

      def deep_extract_preload_options(exposure, options, associations, exposures_with_callbacks) # rubocop:disable Metrics/MethodLength
        key_of_exposure = exposure.instance_variable_get(:@key)
        # Dynamic keys are difficult to handle and less used, skipped directly
        return if key_of_exposure.respond_to?(:call)

        if exposure.is_a?(Grape::Entity::Exposure::NestingExposure)
          extract_preload_options(
            exposure.nested_exposures,
            options.for_nesting(key_of_exposure),
            associations,
            exposures_with_callbacks
          )
        elsif exposure.is_a?(Grape::Entity::Exposure::RepresentExposure) && exposure.preload_association && Preloader.activerecord_gte_7_0? # rubocop:disable Layout/LineLength
          extract_preload_options(
            exposure.using_class.root_exposures,
            options.for_nesting(key_of_exposure),
            associations[exposure.preload_association],
            exposures_with_callbacks
          )
        end
      end

      def association_chain(associations, chain = [])
        associations.each do |key, value|
          chain << key
          association_chain(value, chain) if value.is_a?(Hash)
        end

        chain
      end
    end
  end
end
