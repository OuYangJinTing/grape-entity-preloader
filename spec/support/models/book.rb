# frozen_string_literal: true

class Book < ApplicationRecord
  include Grape::Entity::DSL

  connection.create_table(:books, if_not_exists: true) do |t|
    t.string :name
    t.references :author
  end

  belongs_to :author, foreign_key: :author_id, class_name: 'User'
  with_options(class_name: 'Tag', as: :target, dependent: :destroy) do |assoc|
    assoc.has_many :tags_by_association, -> { annotate('book_tags_by_association') }
    assoc.has_many :tags_by_callback, -> { annotate('book_tags_by_callback') }
  end

  entity do
    expose :name
    expose :tags_by_association, using: 'Tag::Entity', preload_association: :tags_by_association
    expose :tags_by_callback, using: 'Tag::Entity', preload_callback: lambda { |objects, _options|
      ActiveRecord::Associations::Preloader.new(
        records: objects,
        associations: :tags_by_callback
      ).call.first.preloaded_records
    }
    expose :tags_count_by_association, preload_association: :tags_by_association,
                                       preload_condition: ->(options) { options[:expose_book_tags_count_by_association] } # rubocop:disable Layout/LineLength
    expose :tags_count_by_callback, preload_condition: ->(options) { options[:expose_book_tags_count_by_callback] },
                                    preload_callback: lambda { |objects, _options|
                                      ActiveRecord::Associations::Preloader.new(
                                        records: objects,
                                        associations: :tags_by_callback
                                      ).call.first.preloaded_records
                                    }

    def tags_count_by_association
      object.tags_by_association.size
    end

    def tags_count_by_callback
      object.tags_by_callback.size
    end
  end
end
