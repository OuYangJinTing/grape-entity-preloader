# frozen_string_literal: true

require 'grape-entity'
require_relative 'preloader/version'
require_relative 'preloader/endpoint'
require_relative 'preloader/entity'
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
          extract_associations(exposures, associations, options)
          ActiveRecord::Associations::Preloader.new(records: objects, associations: associations).call
        end
      else
        def call
          warn 'The Preloader work normally requires activerecord(>= 7.0) gem'
        end
      end

      private

      def extract_associations(exposures, associations, options)
        exposures.each do |exposure|
          next unless exposure.should_return_key?(options)

          new_associations = associations[exposure.preload] ||= {} if exposure.preload
          key_of_exposure = exposure.instance_variable_get(:@key)
          # Dynamic keys are difficult to handle and less used, skipped directly
          next if key_of_exposure.respond_to?(:call)

          if exposure.is_a?(Exposure::NestingExposure)
            extract_associations(exposure.nested_exposures, associations, options.for_nesting(key_of_exposure))
          elsif exposure.is_a?(Exposure::RepresentExposure) && new_associations
            extract_associations(exposure.using_class.root_exposures, new_associations, options.for_nesting(key_of_exposure))
          end
        end
      end
    end
  end
end
