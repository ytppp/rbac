# 角色序列化器：把 Role 对象转成前端要的 JSON。
class RoleSerializer
  class << self
    # user_count 允许外部传进来（列表页已经批量算好了），
    # 不传时才自己去查一次 count，避免不必要的查询。
    def render(role, include_permissions: true, user_count: nil)
      data = {
        id: role.id,
        name: role.name,
        code: role.code,
        description: role.description,
        # 注意：Rails 7 的 enum 读取器返回字符串（"enabled"），这里统一转成 0/1 给前端
        status: role.enabled? ? 1 : 0,
        status_text: role.enabled? ? "启用" : "禁用",
        # built_in / super_admin 用来告诉前端「这一行不能删、不能改 code」，从而禁用对应按钮
        built_in: role.built_in?,
        super_admin: role.super_admin?,
        user_count: user_count.nil? ? role.users.count : user_count,
        created_at: role.created_at.iso8601,
        updated_at: role.updated_at.iso8601
      }

      # 分配权限的弹窗需要「原本勾选了哪些权限」
      data[:permission_ids] = role.permissions.pluck(:id) if include_permissions

      data
    end

    # 下拉选项用的精简版：字段少一些，只够渲染一个选项即可
    def render_option(role)
      { id: role.id, name: role.name, code: role.code, status: role.enabled? ? 1 : 0 }
    end
  end
end
