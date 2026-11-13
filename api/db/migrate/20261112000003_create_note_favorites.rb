class CreateNoteFavorites < ActiveRecord::Migration[7.1]
  def change
    create_table :note_favorites do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :note, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :note_favorites, [ :user_id, :note_id ], unique: true
  end
end
