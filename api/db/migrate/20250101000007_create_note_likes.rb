# 点赞记录表：记录「哪个用户赞了哪条内容」。
class CreateNoteLikes < ActiveRecord::Migration[7.1]
  def change
    create_table :note_likes do |t|
      t.bigint :user_id, null: false
      t.bigint :note_id, null: false

      t.timestamps
    end

    # 同一用户对同一条内容只能有一条点赞记录（一人一次）
    add_index :note_likes, %i[user_id note_id], unique: true
    add_index :note_likes, :note_id

    add_foreign_key :note_likes, :users, on_delete: :cascade
    add_foreign_key :note_likes, :notes, on_delete: :cascade
  end
end
