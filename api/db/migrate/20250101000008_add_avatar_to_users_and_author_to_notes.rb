# 用户头像、内容作者归属。
class AddAvatarToUsersAndAuthorToNotes < ActiveRecord::Migration[7.1]
  def change
    # 头像地址（可空）：没上传就为 nil，前端回退到「首字母 + 底色」的老逻辑
    add_column :users, :avatar_url, :string

    # 内容作者关联到真实用户（可空）：种子数据等历史内容保持为空
    add_column :notes, :user_id, :bigint
    add_index :notes, :user_id
    # 删除用户时保留其内容，只把作者关联置空
    add_foreign_key :notes, :users, on_delete: :nullify
  end
end
