# frozen_string_literal: true

RSpec.describe Grape::Entity::Preloader::Exposure::Base do
  describe '#initialize' do
    describe 'with :preload_association and :preload_callback option' do
      it 'raise ArgumentError' do
        expect do
          Grape::Entity::Exposure::Base.new(:id, { preload_association: :id, preload_callback: -> { [] } }, {})
        end.to raise_error(ArgumentError)
      end
    end
  end
end
