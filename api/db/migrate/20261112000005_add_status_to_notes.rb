class AddStatusToNotes < ActiveRecord::Migration[7.1]
  def change
    # 0 草稿 / 1 待审 / 2 已发布 / 3 已下架；存量内容默认为已发布
    add_column :notes, :status, :integer, default: 2, null: false
    add_index :notes, :status
  end
end
