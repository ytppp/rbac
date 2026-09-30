# 迁移文件：用 Ruby 代码描述「数据库结构要怎么改」。
#
# 文件名前面的数字是版本号（时间戳），Rails 靠它记录「哪些迁移已经执行过」，
# 执行过的会写进数据库的 schema_migrations 表，所以重复运行也不会重复建表。
#
# 常用命令：
#   bin/rails db:migrate        执行所有还没跑过的迁移
#   bin/rails db:rollback       回退最近一次迁移
#   bin/rails db:prepare        建库 + 执行迁移（本项目 entrypoint 用的就是它）
#
# 一旦某个迁移提交并跑过，就不要再改它的内容（别人机器上已经执行过了），
# 需要调整结构应该新写一个迁移文件。
class CreateUsers < ActiveRecord::Migration[7.1]
  # change 是「可逆」写法：Rails 能从建表语句自动推断出回滚时该做什么（删表）。
  # 如果写的是 up / down 两个方法，就得自己把回滚动作也写一遍。
  def change
    # create_table 会自动加上自增主键 id
    create_table :users do |t|
      t.string :email, null: false              # null: false 表示数据库层面不允许为空
      t.string :name, null: false
      # 密码不是明文存储。has_secure_password 要求列名固定叫 password_digest，
      # 里面存的是 bcrypt 加密后的哈希值。
      t.string :password_digest, null: false
      # 0=禁用 1=启用
      t.integer :status, null: false, default: 1
      t.datetime :last_login_at

      # 这一行会一次性生成 created_at 和 updated_at 两列，
      # Rails 在创建/更新记录时自动维护它们。
      t.timestamps
    end

    # 唯一索引。这里用 lower(email) 而不是直接索引 email 列，
    # 是为了让 'A@x.com' 和 'a@x.com' 被认定为同一个邮箱（大小写不敏感去重）。
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
    # 按状态筛选是高频查询，加索引加快速度
    add_index :users, :status
  end
end
