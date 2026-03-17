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
end
