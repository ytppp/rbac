# 权限表（菜单 + 按钮）：parent_id 指向本表 id，构成一棵树。
class CreatePermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :permissions do |t|
      t.string :name, null: false
      t.string :code, null: false        # 如 system:user:create，前后端校验都用它
      # 0=菜单 1=按钮/接口
      t.integer :type, null: false, default: 0
      t.bigint :parent_id
      t.string :path
      t.string :component                # 留空表示只是目录
      t.string :icon
      t.integer :sort, null: false, default: 0
      # 0=禁用 1=启用
      t.integer :status, null: false, default: 1

      t.timestamps
    end

    add_index :permissions, :code, unique: true
    add_index :permissions, :parent_id
    add_index :permissions, %i[type status]
    # on_delete: :restrict：仍有子节点时由数据库阻止删除
    add_foreign_key :permissions, :permissions, column: :parent_id, on_delete: :restrict
  end
end
