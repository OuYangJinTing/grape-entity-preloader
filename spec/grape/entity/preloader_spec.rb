# frozen_string_literal: true

RSpec.describe Grape::Entity::Preloader do
  it 'has a version number' do
    expect(Grape::Entity::Preloader::VERSION).not_to be_nil
  end

  describe '.with_enable' do
    it 'returns the value of the block' do
      result = described_class.with_enable { 42 }
      expect(result).to eq(42)
    end

    it 'returns the value of the block when already enabled' do
      described_class.enabled!
      result = described_class.with_enable { 'hello' }
      expect(result).to eq('hello')
    ensure
      described_class.disabled!
    end
  end

  describe '.with_disable' do
    it 'returns the value of the block' do
      result = described_class.with_disable { 42 }
      expect(result).to eq(42)
    end

    it 'returns the value of the block when already disabled' do
      described_class.disabled!
      result = described_class.with_disable { 'hello' }
      expect(result).to eq('hello')
    end
  end

  describe 'nested exposure options' do
    def entity_class(paths)
      Class.new(Grape::Entity) do
        expose :a
        expose :embed do
          expose :b do |obj, options|
            paths << options[:attr_path].dup
            obj[:b]
          end
        end
      end
    end

    it 'keeps correct attr_path when preloader is disabled' do
      paths = []
      described_class.with_disable { entity_class(paths).represent({ a: 1, b: 2 }, serializable: true) }
      expect(paths).to eq([%i[embed b]])
    end

    it 'keeps correct attr_path when preloader is enabled' do
      paths = []
      described_class.with_enable { entity_class(paths).represent({ a: 1, b: 2 }, serializable: true) }
      expect(paths).to eq([%i[embed b]])
    end

    it 'provides the same attr_path regardless of preloader state' do
      paths = { disabled: [], enabled: [] }
      described_class.with_disable { entity_class(paths[:disabled]).represent({ a: 1, b: 2 }, serializable: true) }
      described_class.with_enable { entity_class(paths[:enabled]).represent({ a: 1, b: 2 }, serializable: true) }
      expect(paths[:disabled]).to eq(paths[:enabled])
      expect(paths[:enabled]).to eq([%i[embed b]])
    end
  end

  describe 'preload callback deduplication' do
    it 'only calls the same callback once for multiple exposures' do
      calls = []

      callback = lambda do |objects, _options|
        calls << objects
        objects.each do |obj|
          obj.instance_variable_set(:@foo, { value: obj.id })
          obj.instance_variable_set(:@bar, { value: obj.id })
        end
        objects.map { |obj| obj.instance_variable_get(:@foo) }
      end

      item_class = Struct.new(:id)

      child_entity = Class.new(Grape::Entity) do
        expose :value
      end

      parent_entity = Class.new(Grape::Entity) do
        expose :foo, using: child_entity, preload: callback do |obj, _options|
          obj.instance_variable_get(:@foo)
        end

        expose :bar, using: child_entity, preload: callback do |obj, _options|
          obj.instance_variable_get(:@bar)
        end
      end

      objects = [item_class.new(1), item_class.new(2)]
      described_class.with_enable { parent_entity.represent(objects, serializable: true) }

      expect(calls.size).to eq(1)
      expect(calls.first).to eq(objects)
    end
  end
end
