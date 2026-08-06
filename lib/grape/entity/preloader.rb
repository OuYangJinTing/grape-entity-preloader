# frozen_string_literal: true

require 'grape-entity'
require_relative 'preloader/version'
require_relative 'preloader/entity'
require_relative 'preloader/options'
require_relative 'preloader/exposure/base'

module Grape
  class Entity
    class Preloader # rubocop:disable Style/Documentation,Metrics/ClassLength
      attr_reader :exposures, :objects, :options, :associations, :callbacks, :nested_association_chain

      singleton_class.attr_accessor :enabled
      self.enabled = false

      def self.enabled!
        self.enabled = true
      end

      def self.enabled?
        if ActiveSupport::IsolatedExecutionState.key?(:grape_entity_preloader)
          ActiveSupport::IsolatedExecutionState[:grape_entity_preloader]
        else
          enabled
        end
      end

      def self.with_enable # rubocop:disable Metrics/MethodLength
        return yield if enabled?

        begin
          old_value = ActiveSupport::IsolatedExecutionState[:grape_entity_preloader]
          ActiveSupport::IsolatedExecutionState[:grape_entity_preloader] = true

          yield
        ensure
          if old_value.nil?
            ActiveSupport::IsolatedExecutionState.delete(:grape_entity_preloader)
          else
            ActiveSupport::IsolatedExecutionState[:grape_entity_preloader] = old_value
          end
        end
      end

      def self.disabled!
        self.enabled = false
      end

      def self.disabled?
        !enabled?
      end

      def self.with_disable # rubocop:disable Metrics/MethodLength
        return yield if disabled?

        begin
          old_value = ActiveSupport::IsolatedExecutionState[:grape_entity_preloader]
          ActiveSupport::IsolatedExecutionState[:grape_entity_preloader] = false

          yield
        ensure
          if old_value.nil?
            ActiveSupport::IsolatedExecutionState.delete(:grape_entity_preloader)
          else
            ActiveSupport::IsolatedExecutionState[:grape_entity_preloader] = old_value
          end
        end
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
        return if associations.empty?

        # TODO: Change ActiveRecord async query
        ActiveRecord::Associations::Preloader.new(records: objects, associations: associations).call
      rescue => e # rubocop:disable Style/RescueStandardError
        if defined?(ActiveRecord) && ActiveRecord.respond_to?(:version) && ActiveRecord.version >= Gem::Version.new('7.0')
          raise e
        end

        raise 'Preloading associations requires ActiveRecord >= 7.0'
      end

      def execute_preload_callbacks # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity
        callbacks.each do |association_chain, exposures_with_options|
          association_objects = association_chain.inject(objects) do |items, association|
            items.filter_map(&association).flatten(1)
          end
          next if association_objects.empty?

          exposures_with_options.each do |exposure, options|
            callback_objects = exposure.preload_callback.call(association_objects, options)
            # Dynamic keys are difficult to handle and less used, skipped directly
            next if !exposure.is_a?(Grape::Entity::Exposure::RepresentExposure) || exposure_with_dynamic_key?(exposure)

            Preloader.new(
              exposure.using_class.root_exposures,
              callback_objects,
              nesting_options(exposure, options)
            ).call
          end
        end
      end

      def extract_preload_options(exposures, options, associations) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
        exposures.each do |exposure|
          next unless exposure.should_return_key?(options)
          next if exposure.preload_condition && !exposure.preload_condition.call(options)

          if exposure.preload_callback
            callbacks[nested_association_chain.dup] << [exposure, options]
          elsif exposure.preload_association
            associations[exposure.preload_association] ||= {}
          end

          # Dynamic keys are difficult to handle and less used, skipped directly
          next if exposure_with_dynamic_key?(exposure)

          if exposure.is_a?(Grape::Entity::Exposure::NestingExposure)
            extract_preload_options(
              exposure.nested_exposures,
              nesting_options(exposure, options),
              associations
            )
          elsif exposure.is_a?(Grape::Entity::Exposure::RepresentExposure) && associations[exposure.preload_association]
            nested_association_chain.push(exposure.preload_association)
            extract_preload_options(
              exposure.using_class.root_exposures,
              nesting_options(exposure, options),
              associations[exposure.preload_association]
            )
            nested_association_chain.pop
          end
        end
      end

      def nesting_options(exposure, options)
        options.for_nesting(exposure.instance_variable_get(:@key))
      end

      def exposure_with_dynamic_key?(exposure)
        exposure.instance_variable_get(:@key).respond_to?(:call)
      end
    end
  end
end
