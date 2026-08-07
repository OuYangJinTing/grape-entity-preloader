# frozen_string_literal: true

require 'grape-entity'
require_relative 'preloader/version'
require_relative 'preloader/entity'
require_relative 'preloader/options'
require_relative 'preloader/exposure/base'

module Grape
  class Entity
    class Preloader # rubocop:disable Style/Documentation,Metrics/ClassLength
      STATE_KEY = :grape_entity_preloader

      attr_reader :entity_class, :objects, :options, :associations, :callbacks, :nested_association_chain

      singleton_class.attr_accessor :enabled
      self.enabled = false

      def self.enabled!
        self.enabled = true
      end

      def self.disabled!
        self.enabled = false
      end

      def self.enabled?
        if ActiveSupport::IsolatedExecutionState.key?(STATE_KEY)
          ActiveSupport::IsolatedExecutionState[STATE_KEY]
        else
          enabled
        end
      end

      def self.disabled?
        !enabled?
      end

      def self.with_enable(&block)
        enabled? ? yield : with_state(true, &block)
      end

      def self.with_disable(&block)
        disabled? ? yield : with_state(false, &block)
      end

      def self.with_state(value)
        old_value = ActiveSupport::IsolatedExecutionState[STATE_KEY]
        ActiveSupport::IsolatedExecutionState[STATE_KEY] = value

        yield
      ensure
        if old_value.nil?
          ActiveSupport::IsolatedExecutionState.delete(STATE_KEY)
        else
          ActiveSupport::IsolatedExecutionState[STATE_KEY] = old_value
        end
      end

      def initialize(entity_class, objects, options)
        @entity_class = entity_class
        @objects = Array.wrap(objects)
        @options = options

        @associations = {}
        @callbacks = Hash.new { |hash, key| hash[key] = [] }
        @nested_association_chain = []
      end

      def call
        return if objects.empty?

        extract_preload_option(entity_class.root_exposures, options, associations)
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
            next unless exposure.is_a?(Grape::Entity::Exposure::RepresentExposure)

            # Dynamic key are difficult to handle and little used, so skip preloading directly.
            key = exposure.instance_variable_get(:@key)
            if key.respond_to?(:call)
              warn "#{entity_class}.#{exposure.attribute} has dynamic key, preloading is not supported"
              next
            end

            Preloader.new(
              exposure.using_class,
              callback_objects,
              nesting_options_for(options, key)
            ).call
          end
        end
      end

      def extract_preload_option(exposures, options, associations) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
        exposures.each do |exposure| # rubocop:disable Metrics/BlockLength
          key = exposure.instance_variable_get(:@key)
          # Dynamic key or attr_path are difficult to handle and little used, so skip preloading directly.
          if key.respond_to?(:call)
            warn "#{entity_class}.#{exposure.attribute} has dynamic key, preloading is not supported"
            next
          end
          if exposure.instance_variable_get(:@attr_path_proc).respond_to?(:call)
            warn "#{entity_class}.#{exposure.attribute} has dynamic attr_path, preloading is not supported"
            next
          end

          next unless exposure.should_return_key?(options)
          next if exposure.preload_condition && !exposure.preload_condition.call(options)

          if exposure.preload_callback
            callbacks[nested_association_chain.dup] << [exposure, options]
          elsif exposure.preload_association
            associations[exposure.preload_association] ||= {}
          end

          if exposure.is_a?(Grape::Entity::Exposure::NestingExposure)
            options.with_attr_path(key) do
              extract_preload_option(
                exposure.nested_exposures,
                nesting_options_for(options, key),
                associations
              )
            end
          elsif exposure.is_a?(Grape::Entity::Exposure::RepresentExposure) && associations[exposure.preload_association]
            options.with_attr_path(key) do
              nested_association_chain.push(exposure.preload_association)
              extract_preload_option(
                exposure.using_class.root_exposures,
                nesting_options_for(options, key),
                associations[exposure.preload_association]
              )
              nested_association_chain.pop
            end
          end
        end
      end

      def nesting_options_for(options, key)
        key ? options.for_nesting(key) : options
      end
    end
  end
end
