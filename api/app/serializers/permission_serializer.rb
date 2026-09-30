# 权限序列化器。
#
# 权限的字段拼装其实写在 Permission#as_tree_node 里（模型自带的转 JSON 方法），
# 这里主要是复用它，再补上时间字段。
# 这样设计是为了让「树形结构」和「扁平列表」两条路径输出的字段完全一致，
# 前端不用为两种展示各写一套解析逻辑。
class PermissionSerializer
  class << self
    def render(permission)
      # merge 会把两个 Hash 合并（后面的键覆盖前面的同名键）
      permission.as_tree_node.merge(
        created_at: permission.created_at.iso8601,
        updated_at: permission.updated_at.iso8601
      )
    end

    def render_collection(permissions)
      permissions.map { |permission| render(permission) }
    end

    # 上级菜单下拉选项用的精简版
    def render_option(permission)
      {
        id: permission.id,
        name: permission.name,
        code: permission.code,
        type: permission.menu? ? 0 : 1,
        parent_id: permission.parent_id
      }
    end
  end
end
