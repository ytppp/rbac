# 用户模型，对应数据库里的 users 表。
#
# 这个类承担三件事：
#   1. 定义与角色/权限的关联（has_many / has_many ... through）
#   2. 定义数据校验规则（validates）
#   3. 提供「这个用户有哪些权限、能看到哪些菜单」的查询方法
class User < ApplicationRecord
  # Rails 内置的密码功能。它会做两件事：
  #   - 要求数据库有一列 password_digest（存经过 bcrypt 加密后的密码，不是明文）
  #   - 生成 password= / password_confirmation= / authenticate 等方法
  # 所以代码里永远只给 password 赋值，读的时候拿到的是 password_digest。
  has_secure_password

  # 数据库里 status 存的是整数（0/1），但代码里希望写成 :enabled / :disabled 这种可读的名字，
  # 于是用 enum 建立映射。定义之后 Rails 会额外生成一批方法：
  #   user.enabled?  user.disabled?   -> 判断当前值
  #   user.enabled!  user.disabled!   -> 改成对应值并保存
  #   User.enabled                    -> 查询「所有启用用户」的 scope
  # validate: true 表示：如果赋了一个映射表里没有的值，走校验报错，而不是直接抛异常。
  STATUSES = { disabled: 0, enabled: 1 }.freeze
  enum :status, STATUSES, validate: true

  # --- 关联（关系） ---
  # has_many :user_roles 表示「一个用户拥有多条 user_roles 记录」。
  # dependent: :destroy 表示删除用户时，把它在中间表里的记录一并删掉，避免留下孤儿数据。
  has_many :user_roles, dependent: :destroy

  # through 是「多对多」的标准写法：不直接连 roles 表，
  # 而是穿过 user_roles 这张中间表去取角色。
  # 有了这行，user.roles 就能直接拿到该用户的所有角色对象。
  has_many :roles, through: :user_roles

  # --- 校验规则（validates）---
  # 保存前自动执行；不满足条件时 save 返回 false，save! 则抛出 ActiveRecord::RecordInvalid。
  validates :email,
            presence: true,                                          # 必填
            uniqueness: { case_sensitive: false },                   # 唯一（忽略大小写）
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "格式不正确" } # 必须像邮箱

  validates :name, presence: true, length: { maximum: 50 }

  # allow_nil: true 很关键：密码不是直接存库的（存的是 password_digest），
  # 所以「只改昵称、不填密码」的请求也能通过校验，不会被误拦。
  validates :password, length: { minimum: 6, maximum: 72 }, allow_nil: true

  # Rails 7.1 新增的 normalizes：给属性赋值的那一刻就自动做清洗，
  # 存进数据库的永远是规整过的值，省去在控制器里到处 strip/downcase。
  normalizes :email, with: ->(value) { value.to_s.strip.downcase }
  normalizes :name, with: ->(value) { value.to_s.strip }

  # --- scope：可复用的查询片段 ---
  # scope 写起来像变量，用起来像类方法：User.search("abc")
  # 它的返回值是一个「查询对象」，可以继续往后接各种条件（见下面的控制器用法）。
  scope :search, ->(keyword) {
    # lambda 里的 next 等价于 return，表示后面不执行了、直接返回 all（即不加任何过滤）
    next all if keyword.blank?

    # sanitize_sql_like 会把用户输入里的 % 和 _ 转义掉。
    # 否则用户搜一个 "%" 就会变成 SQL 里的通配符，把所有数据都匹配出来。
    pattern = "%#{sanitize_sql_like(keyword.to_s.strip)}%"
    # ILIKE 是 PostgreSQL 的大小写不敏感模糊匹配（LIKE 是大小写敏感的）
    where("users.email ILIKE :pattern OR users.name ILIKE :pattern", pattern: pattern)
  }

  # --- 业务方法 ---

  # 判断这个用户是不是超级管理员（拥有 super_admin 这个角色码）
  def super_admin?
    role_codes.include?(Role::SUPER_ADMIN_CODE)
  end

  # 取出该用户所有角色的 code 数组，例如 ["user_manager"]
  # `@role_codes ||= ...` 是 Ruby 的「记忆化」写法：
  # 第一次调用会查库并把结果存进实例变量，之后再调用直接返回缓存，避免重复查库。
  def role_codes
    @role_codes ||= roles.pluck(:code)
  end

  # 当前用户拥有的全部权限码（只统计「启用状态」的角色与权限）
  def permission_codes
    @permission_codes ||= if super_admin?
      # 超管不用一条条查，直接拿所有启用权限
      Permission.active.pluck(:code).uniq
    else
      # joins 对应 SQL 的 JOIN：把权限表沿着 中间表 -> 角色 -> 中间表 一路连起来
      # role_permissions: { role: :user_roles } 这种嵌套写法，表示「顺着关联再关联」
      Permission
        .joins(role_permissions: { role: :user_roles })
        .where(user_roles: { user_id: id })                       # 只看属于我的关联行
        .where(roles: { status: Role.statuses[:enabled] })        # 角色必须是启用的
        .where(permissions: { status: Permission.statuses[:enabled] }) # 权限必须是启用的
        .distinct                                                 # 去重，避免多角色造成重复行
        .pluck(:code)                                             # 只取 code 列，返回数组
    end
  end

  # 当前用户可见的菜单（type=menu 且启用），按 sort 升序。
  # 前端拿这个结果生成动态路由和侧边栏，所以「没有权限的菜单」根本不会出现在前端。
  def menu_permissions
    # 超管直接返回全部启用菜单
    return Permission.active.menus.sorted if super_admin?

    Permission
      .active
      .menus
      .joins(role_permissions: { role: :user_roles })
      .where(user_roles: { user_id: id })
      .where(roles: { status: Role.statuses[:enabled] })
      .distinct
      .sorted
  end

  # 手动清掉上面两处记忆化缓存。
  # 场景：刚给用户改了角色，如果不清理，permission_codes 还会返回改之前的结果。
  def reload_permissions!
    @role_codes = nil
    @permission_codes = nil
    self
  end
end
