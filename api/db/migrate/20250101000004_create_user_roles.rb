# 「用户 - 角色」中间表（连接表）。
#
# 多对多关系在关系型数据库里的标准解法：
#   既然做不到「用户表里存一列角色列表」，就拆出一张只有两列外键的小表。
#
# 这张表本身几乎没有业务字段，它的存在意义就是「一对一对地记录谁拥有什么」。
class CreateUserRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :user_roles do |t|
      # t.references 是下面两行的语法糖：
      #   t.bigint :user_id, null: false
      #   add_index :user_roles, :user_id
      # 再配合 null: false + 外键约束，保证 user_id 一定指向真实存在的用户。
      # on_delete: :cascade 表示「用户被删掉时，这里的关联记录也自动删掉」，
      # 由数据库来保证不留垃圾数据（即使绕过 Rails 直接删库也一样有效）。
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :role, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    # 唯一约束：防止同一个人被重复分配同一个角色。
    # 这和模型里 validates :user_id, uniqueness: { scope: :role_id } 是同一件事的
    # 「数据库层保险」——模型校验可能被绕过（比如并发写入），数据库约束不会。
    add_index :user_roles, %i[user_id role_id], unique: true
  end
end
