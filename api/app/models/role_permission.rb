# 「角色 - 权限」的中间表模型（多对多关系的连接表）。
#
# 与 UserRole 是同一个套路：
#   一个角色可以拥有多个权限，一个权限也可以被多个角色拥有，
#   所以拆出一张只存「哪个角色(role_id) 拥有 哪个权限(permission_id)」的表。
#   roles  <-- role_permissions -->  permissions
#
# 整个 RBAC 的三级关系就靠这两张中间表串起来：
#   用户 --user_roles--> 角色 --role_permissions--> 权限
class RolePermission < ApplicationRecord
  belongs_to :role
  belongs_to :permission

  # 同一对（角色, 权限）只能出现一次
  validates :role_id, uniqueness: { scope: :permission_id }
end
