# 角色表：把一批权限打包成一个身份，便于批量授权。
class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :description
      # 0=禁用 1=启用
      t.integer :status, null: false, default: 1
      t.boolean :built_in, null: false, default: false

      t.timestamps
    end

    add_index :roles, :code, unique: true
    add_index :roles, :status
  end
end
