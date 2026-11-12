class CreateComments < ActiveRecord::Migration[7.1]
  def change
    create_table :comments do |t|
      t.references :note, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      # 回复：指向同一条内容下的顶层评论；顶层评论该字段为空
      t.references :parent, null: true, foreign_key: { to_table: :comments, on_delete: :cascade }
      t.text :content, null: false
      t.integer :likes_count, default: 0, null: false

      t.timestamps
    end

    add_index :comments, [ :note_id, :created_at ]
  end
end
