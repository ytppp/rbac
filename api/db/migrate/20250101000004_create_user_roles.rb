# 「用户 - 角色」中间表，承载多对多关系。
class CreateUserRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :role, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    # 唯一约束：防止同一用户被重复分配同一角色
    add_index :user_roles, %i[user_id role_id], unique: true
  end
end
