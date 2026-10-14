# 「角色 - 权限」中间表，承载多对多关系。
class CreateRolePermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :role_permissions do |t|
      t.references :role, null: false, foreign_key: { on_delete: :cascade }
      t.references :permission, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    # 同一个角色不能重复拥有同一个权限
    add_index :role_permissions, %i[role_id permission_id], unique: true
  end
end
