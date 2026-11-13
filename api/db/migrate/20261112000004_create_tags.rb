class CreateTags < ActiveRecord::Migration[7.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.integer :notes_count, default: 0, null: false
      t.integer :sort, default: 0, null: false

      t.timestamps
    end

    add_index :tags, :name, unique: true

    create_table :note_tags do |t|
      t.references :note, null: false, foreign_key: { on_delete: :cascade }
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :note_tags, [ :note_id, :tag_id ], unique: true
  end
end
