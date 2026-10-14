# 内容社区（app 模块）的表，为 Nuxt 首页瀑布流提供卡片内容。
class CreateNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :notes do |t|
      t.string :title, null: false
      t.string :cover_url, null: false
      # 宽/高比值，用 decimal 定点小数避免浮点精度误差
      t.decimal :cover_ratio, precision: 6, scale: 4, null: false, default: 1.0
      t.string :author_name, null: false
      t.string :avatar_color, null: false, default: "#ff6b6b"
      t.integer :likes_count, null: false, default: 0
      t.string :channel, null: false
      t.integer :sort, null: false, default: 0

      t.timestamps
    end

    add_index :notes, :channel
    add_index :notes, :sort
  end
end
