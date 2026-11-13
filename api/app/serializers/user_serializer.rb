# 用户序列化器：把 User 对象转成前端需要的 JSON 结构。
class UserSerializer
  class << self
    def render(user, include_roles: true)
      data = {
        id: user.id,
        email: user.email,
        name: user.name,
        status: user.enabled? ? 1 : 0,
        status_text: user.enabled? ? "启用" : "禁用",
        # 头像地址，没上传时为 nil（前端回退到首字母）
        avatar_url: user.avatar_url,
        last_login_at: user.last_login_at&.iso8601,
        created_at: user.created_at.iso8601,
        updated_at: user.updated_at.iso8601
      }

      if include_roles
        roles = user.association(:roles).loaded? ? user.roles : user.roles.order(:id)
        data[:roles] = roles.map { |role| { id: role.id, name: role.name, code: role.code } }
        data[:role_ids] = roles.map(&:id)
      end

      data
    end

    def render_collection(users)
      users.map { |user| render(user) }
    end
  end
end
