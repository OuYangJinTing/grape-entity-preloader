# frozen_string_literal: true

class User < ApplicationRecord
  include Grape::Entity::DSL

  connection.create_table(:users, if_not_exists: true) do |t|
    t.string :name
  end

  with_options(class_name: 'Book', foreign_key: :author_id, dependent: :destroy) do |assoc|
    assoc.has_many :books_by_association, -> { annotate('user_books_by_association') }
    assoc.has_many :books_by_callback, -> { annotate('user_books_by_callback') }
  end

  with_options(class_name: 'Tag', as: :target, dependent: :destroy) do |assoc|
    assoc.has_many :tags_by_association, -> { annotate('user_tags_by_association') }
    assoc.has_many :tags_by_callback, -> { annotate('user_tags_by_callback') }
  end

  entity do
    expose :name

    expose :books_by_association, using: 'Book::Entity', preload_association: :books_by_association
    expose :books_by_callback, using: 'Book::Entity', preload_callback: lambda { |objects, _options|
      ActiveRecord::Associations::Preloader.new(
        records: objects,
        associations: :books_by_callback
      ).call.first.preloaded_records
    }
    expose :books_count_by_association, preload_association: :books_by_association,
                                        preload_condition: ->(options) { options[:expose_books_count_by_association] }
    expose :books_count_by_callback, preload_condition: ->(options) { options[:expose_books_count_by_callback] },
                                     preload_callback: lambda { |objects, _options|
                                       ActiveRecord::Associations::Preloader.new(
                                         records: objects,
                                         associations: :books_by_callback
                                       ).call.first.preloaded_records
                                     }

    expose :tags_by_association, using: 'Tag::Entity', preload_association: :tags_by_association
    expose :tags_by_callback, using: 'Tag::Entity', preload_callback: lambda { |objects, _options|
      ActiveRecord::Associations::Preloader.new(
        records: objects,
        associations: :tags_by_callback
      ).call.first.preloaded_records
    }
    expose :tags_count_by_association, preload_association: :tags_by_association,
                                       preload_condition: ->(options) { options[:expose_user_tags_count_by_association] } # rubocop:disable Layout/LineLength
    expose :tags_count_by_callback, preload_condition: ->(options) { options[:expose_user_tags_count_by_callback] },
                                    preload_callback: lambda { |objects, _options|
                                      ActiveRecord::Associations::Preloader.new(
                                        records: objects,
                                        associations: :tags_by_callback
                                      ).call.first.preloaded_records
                                    }

    def books_count_by_association
      object.books_by_association.size
    end

    def books_count_by_callback
      object.books_by_callback.size
    end

    def tags_count_by_association
      object.tags_by_association.size
    end

    def tags_count_by_callback
      object.tags_by_callback.size
    end
  end
end
