# 「角色 - 权限」中间表模型（多对多连接表）。
class RolePermission < ApplicationRecord
  belongs_to :role
  belongs_to :permission

  # 同一对（角色, 权限）只能出现一次
  validates :role_id, uniqueness: { scope: :permission_id }
end
