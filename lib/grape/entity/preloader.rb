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

      def initialize(exposures, objects, options)
        @exposures = exposures
        @objects = Array.wrap(objects)
        @options = options
      end

      if defined?(ActiveRecord) && ActiveRecord.respond_to?(:version) && ActiveRecord.version >= Gem::Version.new('7.0')
        def call
          associations = {}
          exposures_with_callback = {}
          extract_preload_options(exposures, options, associations, exposures_with_callback)

          # TODO: Change ActiveRecord async query
          ActiveRecord::Associations::Preloader.new(records: objects, associations: associations).call

          exposures_with_callback.each do |association_paths, (exposure, options)|
            association_objects = objects
            association_paths.split('.').each do |association_path|
              association_objects = association_objects.map { |object| object.send(association_path) }.flatten(1)
            end
            callback_objects = exposure.preload_callback.call(association_objects)

            if exposure.is_a?(Exposure::RepresentExposure)
              Preloader.new(exposure.using_class.root_exposures, callback_objects, options).call
            end
          end
        end
      else
        def call
          warn 'The Preloader work normally requires activerecord(>= 7.0) gem'
        end
      end

      private

      def extract_preload_options(exposures, options, associations, exposures_with_callback)
        exposures.each do |exposure|
          next unless exposure.should_return_key?(options)
          next exposures_with_callback[associations.keys.join('.')] = [exposure, options] if exposure.preload_callback

          new_associations = associations[exposure.preload_association] ||= {} if exposure.preload_association

          key_of_exposure = exposure.instance_variable_get(:@key)
          # Dynamic keys are difficult to handle and less used, skipped directly
          next if key_of_exposure.respond_to?(:call)

          if exposure.is_a?(Exposure::NestingExposure)
            extract_preload_options(exposure.nested_exposures, options.for_nesting(key_of_exposure), associations, exposures_with_callback)
          elsif exposure.is_a?(Exposure::RepresentExposure) && new_associations
            extract_preload_options(exposure.using_class.root_exposures, options.for_nesting(key_of_exposure), new_associations, exposures_with_callback)
          end
        end
      end
    end
  end
end
