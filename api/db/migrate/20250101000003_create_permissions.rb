# 权限表（菜单 + 按钮都存在这里）。
#
# 这张表的结构最值得留意的是 parent_id —— 它指向同一张表的 id，
# 于是所有记录天然形成一棵树：
#   系统管理 -> 用户管理 -> 查询用户
class CreatePermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :permissions do |t|
      t.string :name, null: false
      t.string :code, null: false        # 如 system:user:create，后端校验和前端判断都用它
      # 0=菜单 1=按钮/接口
      t.integer :type, null: false, default: 0
      # 指向本表的 id：为 nil 表示这是根节点，否则表示自己的上级是谁。
      # 用 bigint 是为了和 Rails 默认的自增主键类型保持一致。
      t.bigint :parent_id
      # 前端路由信息（type=菜单 时有效）
      t.string :path                     # 路由地址，如 /system/user
      t.string :component                # 组件路径，如 system/user/index；留空表示只是目录
      t.string :icon
      t.integer :sort, null: false, default: 0
      # 0=禁用 1=启用
      t.integer :status, null: false, default: 1

      t.timestamps
    end

    add_index :permissions, :code, unique: true
    # 树形结构每次组装都要按 parent_id 找子节点，加索引很有必要
    add_index :permissions, :parent_id
    # 复合索引：索引多个列，专门针对「同时按 type 和 status 过滤」这种查询
    add_index :permissions, %i[type status]
    # 外键约束：parent_id 必须能对应到 permissions 表里真实存在的 id。
    # on_delete: :restrict 表示「下面还有子节点时，数据库层面直接阻止删除」，
    # 这是比应用层校验更硬的一道保险。
    add_foreign_key :permissions, :permissions, column: :parent_id, on_delete: :restrict
  end
end
