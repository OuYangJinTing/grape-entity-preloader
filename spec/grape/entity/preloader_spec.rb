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

    it 'keeps correct attr_path when as_json is called after serializable: false with arrays' do
      paths = []
      described_class.with_enable { entity_class(paths).represent([{ a: 1, b: 2 }], serializable: false).as_json }
      expect(paths).to eq([%i[embed b]])
    end
  end

  describe 'preload callback deduplication' do
    it 'only calls the same callback once for multiple exposures' do
      calls = []
      item_class = Struct.new(:id)

      callback = lambda do |objects, _options|
        calls << objects
        objects.to_h { |obj| [obj, { value: obj.id }] }
      end

      child_entity = Class.new(Grape::Entity) do
        expose :value
      end

      parent_entity = Class.new(Grape::Entity) do
        expose :foo, using: child_entity, preload: callback do |obj, _options|
          { value: obj.id }
        end

        expose :bar, using: child_entity, preload: callback do |obj, _options|
          { value: obj.id }
        end
      end

      objects = [item_class.new(1), item_class.new(2)]
      described_class.with_enable { parent_entity.represent(objects) }

      expect(calls.size).to eq(1)
      expect(calls.first).to eq(objects)
    end
  end

  describe 'preload cache isolation across nesting levels' do
    it 'does not share parent cache with nested cache for the same object and callback' do
      item_class = Struct.new(:id, :child)
      calls = []
      callback = lambda do |objects, _options|
        call_index = calls.size
        calls.concat(objects)
        objects.to_h { |obj| [obj, { call_index: call_index }] }
      end

      child_entity = Class.new(Grape::Entity) do
        expose :id
        expose :meta, preload: callback
      end

      parent_entity = Class.new(Grape::Entity) do
        expose :id
        expose :meta, preload: callback
        expose :child, using: child_entity, preload: ->(objects, _options) { objects.to_h { |obj| [obj, obj.child] } }
      end

      parent = item_class.new(1, nil)
      parent.child = parent

      result = described_class.with_enable { parent_entity.represent(parent, serializable: true) }

      expect(calls.size).to eq(2)
      expect(result[:meta]).to eq({ call_index: 0 })
      expect(result[:child][:meta]).to eq({ call_index: 1 })
    end
  end

  describe 'circular entity references' do
    it 'does not recurse infinitely when extracting preload options for mutually referencing entities' do
      item_class = Struct.new(:id, :child, :parent)

      child_entity = Class.new(Grape::Entity)
      parent_entity = Class.new(Grape::Entity) do
        expose :id
        expose :child, using: child_entity, preload: :child
      end
      child_entity.class_eval do
        expose :id
        expose :parent, using: parent_entity, preload: :parent
      end

      parent = item_class.new(1, nil, nil)
      child = item_class.new(2, nil, parent)
      parent.child = child

      options = Grape::Entity::Options.new({})
      preloader = described_class.new(parent_entity, [parent], options)

      expect do
        preloader.send(
          :extract_preload_option,
          parent_entity.root_exposures,
          options,
          {},
          [parent_entity]
        )
      end.not_to raise_error
    end
  end

  describe 'deferred serialization with serializable: false' do
    it 'does not preload nested exposures twice when as_json is called later' do
      item_class = Struct.new(:id, :child)
      calls = []
      callback = lambda do |objects, _options|
        call_index = calls.size
        calls.concat(objects)
        objects.to_h { |obj| [obj, { call_index: call_index }] }
      end

      child_entity = Class.new(Grape::Entity) do
        expose :id
        expose :meta, preload: callback
      end

      parent_entity = Class.new(Grape::Entity) do
        expose :id
        expose :meta, preload: callback
        expose :child, using: child_entity, preload: ->(objects, _options) { objects.to_h { |obj| [obj, obj.child] } }
      end

      parent = item_class.new(1, nil)
      parent.child = parent

      result = described_class.with_enable { parent_entity.represent(parent, serializable: false).as_json }

      expect(calls.size).to eq(2)
      expect(result[:meta]).to eq({ call_index: 0 })
      expect(result[:child][:meta]).to eq({ call_index: 1 })
    end

    it 'keeps nested preload cache when as_json is called after serializable: false with arrays' do
      item_class = Struct.new(:id, :child)
      calls = []
      callback = lambda do |objects, _options|
        call_index = calls.size
        calls.concat(objects)
        objects.to_h { |obj| [obj, { call_index: call_index }] }
      end

      child_entity = Class.new(Grape::Entity) do
        expose :id
        expose :meta, preload: callback
      end

      parent_entity = Class.new(Grape::Entity) do
        expose :id
        expose :meta, preload: callback
        expose :child, using: child_entity, preload: ->(objects, _options) { objects.to_h { |obj| [obj, obj.child] } }
      end

      parent = item_class.new(1, nil)
      parent.child = parent

      result = described_class.with_enable { parent_entity.represent([parent], serializable: false).as_json }

      expect(calls.size).to eq(2)
      expect(result.first[:meta]).to eq({ call_index: 0 })
      expect(result.first[:child][:meta]).to eq({ call_index: 1 })
    end
  end
end
