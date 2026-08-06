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
end
