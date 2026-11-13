class CreateReports < ActiveRecord::Migration[7.1]
  def change
    create_table :reports do |t|
      t.references :note, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :reason, null: false
      t.text :detail
      # 0 待处理 / 1 已处理 / 2 已忽略
      t.integer :status, default: 0, null: false
      t.bigint :handled_by
      t.datetime :handled_at

      t.timestamps
    end

    add_index :reports, [ :note_id, :user_id ], unique: true
    add_index :reports, :status
    add_foreign_key :reports, :users, column: :handled_by, on_delete: :nullify
  end
end
