# 内容社区（app 模块）的表。
#
# 这张表和 RBAC 那四张表没有任何关联，是独立的一块业务数据，
# 用来给 Nuxt 首页的瀑布流提供卡片内容。
class CreateNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :notes do |t|
      t.string :title, null: false
      t.string :cover_url, null: false
      # 封面宽高比（宽 / 高），前端用来在图片加载前占位，避免瀑布流抖动。
      # decimal 是定点小数类型：precision: 6 表示总共 6 位有效数字，
      # scale: 4 表示小数点后 4 位，所以能存 0.0001 ~ 99.9999 之间的值。
      # 用 decimal 而不是 float，是因为 float 有精度误差，比值这种数据不希望出现 0.30000000004。
      t.decimal :cover_ratio, precision: 6, scale: 4, null: false, default: 1.0
      t.string :author_name, null: false
      t.string :avatar_color, null: false, default: "#ff6b6b"
      t.integer :likes_count, null: false, default: 0
      t.string :channel, null: false
      t.integer :sort, null: false, default: 0

      t.timestamps
    end

    # 按频道筛选是首页最常用的操作，所以给 channel 建索引
    add_index :notes, :channel
    # 排序也走 sort 列，同样建索引
    add_index :notes, :sort
  end
end
