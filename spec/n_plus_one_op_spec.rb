# frozen_string_literal: true

RSpec.describe 'N+1 operation' do # rubocop:disable RSpec/DescribeClass
  before(:context) do
    Grape::Entity::Preloader.enabled!

    user1 = User.create(name: 'User1')
    user2 = User.create(name: 'User2')

    book1 = Book.create(name: 'Book1', author: user1)
    book2 = Book.create(name: 'Book2', author: user2)

    Tag.create(name: 'UserTag1', target: user1)
    Tag.create(name: 'UserTag2', target: user1)

    Tag.create(name: 'BookTag1', target: book1)
    Tag.create(name: 'BookTag2', target: book2)
  end

  describe 'preloader enabled & disabled' do
    let!(:books) { Book.all.load }

    before do
      Grape::Entity::Preloader.enabled = false # restore default value
    end

    describe 'enabled' do
      it '.enabled!' do
        Grape::Entity::Preloader.enabled!
        expect(Grape::Entity::Preloader.enabled?).to be(true)

        expect do
          Book::Entity.represent(books, serializable: true, only: [:tags_by_association])
        end.to make_database_queries(count: 1)
           .and make_database_queries(
             count: 1,
             matching: /SELECT "tags".* FROM "tags" WHERE "tags"."target_type" = \? AND "tags"."target_id" IN/
           )
      end

      it '.with_enable' do
        Grape::Entity::Preloader.with_enable do
          expect(Grape::Entity::Preloader.enabled?).to be(true)

          expect do
            Book::Entity.represent(books, serializable: true, only: [:tags_by_association])
          end.to make_database_queries(count: 1)
             .and make_database_queries(
               count: 1,
               matching: /SELECT "tags".* FROM "tags" WHERE "tags"."target_type" = \? AND "tags"."target_id" IN/
             )
        end

        expect(Grape::Entity::Preloader.disabled?).to be(true)
      end
    end

    describe 'disabled' do
      it '.disabled!' do
        Grape::Entity::Preloader.disabled!
        expect(Grape::Entity::Preloader.disabled?).to be(true)

        expect do
          Book::Entity.represent(books, serializable: true, only: [:tags_by_association])
        end.to make_database_queries(count: 2)
           .and make_database_queries(
             count: 2,
             matching: /SELECT "tags".* FROM "tags" WHERE "tags"."target_id" = \? AND "tags"."target_type" = \?/
           )
      end

      it '.with_disable' do
        Grape::Entity::Preloader.enabled!
        Grape::Entity::Preloader.with_disable do
          expect(Grape::Entity::Preloader.disabled?).to be(true)

          expect do
            Book::Entity.represent(books, serializable: true, only: [:tags_by_association])
          end.to make_database_queries(count: 2)
             .and make_database_queries(
               count: 2,
               matching: /SELECT "tags".* FROM "tags" WHERE "tags"."target_id" = \? AND "tags"."target_type" = \?/
             )
        end
        expect(Grape::Entity::Preloader.enabled?).to be(true)
      end
    end
  end

  describe 'preload' do
    let!(:users) { User.all.load }
    let!(:books) { Book.all.load }

    describe 'association' do
      it 'single' do
        books = Book.all.load
        expect do
          Book::Entity.represent(books, serializable: true, only: %i[tags_by_association])
        end.to make_database_queries(count: 1)
          .and make_database_queries(count: 1, matching: /book_tags_by_association/)
      end

      it 'nested' do
        expect do
          User::Entity.represent(
            users,
            serializable: true,
            only: [{ books_by_association: %i[tags_by_association tags_by_callback] }]
          )
        end.to make_database_queries(count: 3)
          .and make_database_queries(count: 1, matching: /user_books_by_association/)
          .and make_database_queries(count: 1, matching: /book_tags_by_association/)
          .and make_database_queries(count: 1, matching: /book_tags_by_callback/)
      end

      it 'same preload_association(single preload_association after nested preload_association)' do
        options = {
          serializable: true,
          expose_books_count_by_association: true,
          only: %i[books_count_by_association]
        }

        expect do
          User::Entity.represent(users, options)
        end.to make_database_queries(count: 1)
          .and make_database_queries(count: 1, matching: /user_books_by_association/)

        users.map(&:reload)

        options[:only] << { books_by_association: [:tags_by_association] }
        expect do
          User::Entity.represent(users, options)
        end.to make_database_queries(count: 2)
          .and make_database_queries(count: 1, matching: /user_books_by_association/)
          .and make_database_queries(count: 1, matching: /book_tags_by_association/)
      end
    end

    describe 'callback' do
      it 'single' do
        expect do
          Book::Entity.represent(books, serializable: true, only: %i[tags_by_callback])
        end.to make_database_queries(count: 1)
          .and make_database_queries(count: 1, matching: /book_tags_by_callback/)
      end

      it 'nested' do
        expect do
          User::Entity.represent(
            users,
            serializable: true,
            only: [{ books_by_callback: %i[tags_by_association tags_by_callback] }]
          )
        end.to make_database_queries(count: 3)
          .and make_database_queries(count: 1, matching: /books_by_callback/)
          .and make_database_queries(count: 1, matching: /book_tags_by_association/)
          .and make_database_queries(count: 1, matching: /book_tags_by_callback/)
      end
    end

    describe 'condition' do
      it 'true' do
        expect do
          Book::Entity.represent(
            books,
            serializable: true,
            expose_book_tags_count_by_association: true,
            only: %i[tags_count_by_association]
          )
        end.to make_database_queries(count: 1)
          .and make_database_queries(count: 1, matching: /book_tags_by_association/)
      end

      it 'false' do
        expect do
          Book::Entity.represent(
            books,
            serializable: true,
            expose_book_tags_count_by_association: false,
            only: %i[tags_count_by_association]
          )
        end.to make_database_queries(count: 2)
          .and make_database_queries(count: 2, matching: /book_tags_by_association/)
      end
    end
  end
end
