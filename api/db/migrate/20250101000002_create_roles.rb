# 角色表。
#
# 角色的作用是把「一批权限」打包成一个身份，比如「用户管理员」，
# 这样给新同事开账号时只需要分配一个角色，而不用逐条勾权限。
class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false        # 显示名，如「用户管理员」
      t.string :code, null: false        # 程序内部用的标识，如 user_manager
      t.string :description
      # 0=禁用 1=启用
      t.integer :status, null: false, default: 1
      # 内置角色（超管）不允许删除或改 code
      t.boolean :built_in, null: false, default: false

      t.timestamps
    end

    # code 是程序判断权限时用的凭据，必须唯一（否则两个同名角色会混淆）
    add_index :roles, :code, unique: true
    add_index :roles, :status
  end
end
