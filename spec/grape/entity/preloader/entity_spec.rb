# frozen_string_literal: true

RSpec.describe Grape::Entity::Preloader::Entity do
  module Entities
    class Book < Grape::Entity
      expose :id
    end

    class User < Grape::Entity
      expose :id
      expose :books, using: Book
    end
  end

  describe '#represent' do
    let(:exposures) { Entities::User.root_exposures }
    let(:users) { [{ books: [{ id: 1 }] }] }
    let(:options) { Grape::Entity::Options.new(serializable: true, enable_preloader: true) }
    let(:preloader) { Grape::Entity::Preloader.new(exposures, users, options) }

    describe 'with :enable_preloader option is true' do
      it 'call Preloader#call' do
        expect(Grape::Entity::Preloader).to receive(:new).with(exposures, users, options).and_return(preloader)
        expect(preloader).to receive(:call).and_call_original

        Entities::User.represent(users, options)
      end

      it 'recursive call #represent, call Preloader#call once' do
        expect(Entities::User).to receive(:represent).at_least(:once).and_call_original
        expect(Entities::Book).to receive(:represent).at_least(:once).and_call_original

        expect(Grape::Entity::Preloader).to receive(:new).with(exposures, users, options).and_return(preloader)
        expect(preloader).to receive(:call).once.and_call_original

        Entities::User.represent(users, options)
      end
    end

    it 'with :enable_preloader option is false or without :enable_preloader option, not call Preloader#call' do
      expect(Grape::Entity::Preloader).not_to receive(:new)

      Entities::User.represent(users, serializable: true, enable_preloader: false)
      Entities::User.represent(users, serializable: true)
    end
  end
end
