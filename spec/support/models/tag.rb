# frozen_string_literal: true

class Tag < ApplicationRecord
  include Grape::Entity::DSL

  connection.create_table(:tags, if_not_exists: true) do |t|
    t.string :name
    t.references :target, polymorphic: true
  end

  belongs_to :target, polymorphic: true

  entity do
    expose :name
  end
end
