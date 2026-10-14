# 权限序列化器：复用 Permission#as_tree_node，并补齐时间字段。
class PermissionSerializer
  class << self
    def render(permission)
      permission.as_tree_node.merge(
        created_at: permission.created_at.iso8601,
        updated_at: permission.updated_at.iso8601
      )
    end

    def render_collection(permissions)
      permissions.map { |permission| render(permission) }
    end

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
