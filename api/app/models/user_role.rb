# 「用户 - 角色」的中间表模型（多对多关系的连接表）。
#
# 为什么需要它？
#   一个用户可以有好几个角色，一个角色也能被好几个人拥有，
#   这种「多对多」关系在数据库里没法用一列表达，
#   于是拆成一张只存「谁(user_id) 拥有 哪个角色(role_id)」的中间表。
#   users  <-- user_roles -->  roles
class UserRole < ApplicationRecord
  # belongs_to 表示「属于」：这条记录的 user_id 必须能在 users 表里找到对应行。
  # 它还会自动生成 user / user= 等一组方法。
  belongs_to :user
  belongs_to :role

  # 同一对（用户, 角色）只能出现一次，防止重复分配同一个角色。
  # scope: :role_id 的意思是「在 role_id 相同的前提下，user_id 不能重复」。
  validates :user_id, uniqueness: { scope: :role_id }
end
