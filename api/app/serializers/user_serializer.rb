# 用户序列化器：负责把 User 对象「翻译」成前端要的 JSON 结构。
#
# 为什么要有这一层，而不是直接 render json: user？
#   1. 直接返回模型会把 password_digest 这类敏感字段也暴露出去
#   2. 前端想要的字段名和数据库列名并不总是一致（如 status 要转成 0/1）
#   3. 字段格式需要统一处理（时间转成 ISO8601 字符串）
#
# 这里用 class << self 打开类方法区，所以调用方式是 UserSerializer.render(user)，
# 而不是 UserSerializer.new.render(user) —— 不需要实例，纯函数式的写法。
class UserSerializer
  class << self
    # include_roles: true 表示默认把角色信息也一并带上；
    # 个别场景不需要时可以传 false 省掉这部分查询。
    def render(user, include_roles: true)
      data = {
        id: user.id,
        email: user.email,
        name: user.name,
        # 注意：Rails 7 的 enum 读取器返回字符串（"enabled"），这里统一转成 0/1 给前端
        status: user.enabled? ? 1 : 0,
        status_text: user.enabled? ? "启用" : "禁用",
        # &. 是安全调用：last_login_at 可能是 nil（从没登录过），
        # 如果直接 .iso8601 会报错，用 &. 则整体返回 nil。
        last_login_at: user.last_login_at&.iso8601,
        created_at: user.created_at.iso8601,
        updated_at: user.updated_at.iso8601
      }

      if include_roles
        # association(:roles).loaded? 判断「角色是否已经被提前加载过」：
        #   - 已加载（控制器里用了 includes）就直接用，省一次查询
        #   - 没加载就自己 order 一下再查
        roles = user.association(:roles).loaded? ? user.roles : user.roles.order(:id)
        data[:roles] = roles.map { |role| { id: role.id, name: role.name, code: role.code } }
        # role_ids 是给前端编辑弹窗「回显勾选了哪些角色」用的
        data[:role_ids] = roles.map(&:id)
      end

      data
    end

    # 列表场景：传进来一个用户数组/查询结果，逐个转成上面的结构
    def render_collection(users)
      users.map { |user| render(user) }
    end
  end
end
