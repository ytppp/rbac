# 「用户 - 角色」中间表模型（多对多连接表）。
class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :role

  # 同一对（用户, 角色）只能出现一次，防止重复分配
  validates :user_id, uniqueness: { scope: :role_id }
end
