# 角色序列化器：把 Role 对象转成前端需要的 JSON。
class RoleSerializer
  class << self
    def render(role, include_permissions: true, user_count: nil)
      data = {
        id: role.id,
        name: role.name,
        code: role.code,
        description: role.description,
        status: role.enabled? ? 1 : 0,
        status_text: role.enabled? ? "启用" : "禁用",
        # built_in / super_admin 用于让前端禁用「删除 / 改 code」按钮
        built_in: role.built_in?,
        super_admin: role.super_admin?,
        user_count: user_count.nil? ? role.users.count : user_count,
        created_at: role.created_at.iso8601,
        updated_at: role.updated_at.iso8601
      }

      data[:permission_ids] = role.permissions.pluck(:id) if include_permissions

      data
    end

    def render_option(role)
      { id: role.id, name: role.name, code: role.code, status: role.enabled? ? 1 : 0 }
    end
  end
end
