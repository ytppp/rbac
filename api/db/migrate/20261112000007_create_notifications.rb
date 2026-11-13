class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      # 触发者：评论 / 点赞的人，审核通知时为空
      t.bigint :actor_id
      # comment / like / review
      t.string :action, null: false
      t.references :note, null: true, foreign_key: { on_delete: :cascade }
      t.bigint :comment_id
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :user_id, :read_at ]
    add_foreign_key :notifications, :users, column: :actor_id, on_delete: :nullify
  end
end
