# 「角色 - 权限」中间表（连接表）。
#
# 和 user_roles 是完全同一个套路，只是把两端换成了角色和权限：
#   roles  <-- role_permissions -->  permissions
#
# 到这里，RBAC 的完整链路就串起来了：
#   用户 --(user_roles)--> 角色 --(role_permissions)--> 权限
# 代码里 User#permission_codes 那个略长的 joins 查询，连的就是这两张表。
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
