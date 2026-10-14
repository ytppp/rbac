# 迁移文件：用 Ruby 描述数据库结构变更（文件名前缀为版本号，Rails 据此记录执行状态）。
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :password_digest, null: false
      # 0=禁用 1=启用
      t.integer :status, null: false, default: 1
      t.datetime :last_login_at

      t.timestamps
    end

    # 用 lower(email) 索引，让大小写不同视为同一邮箱
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
    add_index :users, :status
  end
end
