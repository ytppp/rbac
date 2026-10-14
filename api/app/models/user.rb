# 用户模型，对应 users 表。
class User < ApplicationRecord
  has_secure_password

  STATUSES = { disabled: 0, enabled: 1 }.freeze
  enum :status, STATUSES, validate: true

  # --- 关联 ---
  has_many :user_roles, dependent: :destroy

  has_many :roles, through: :user_roles

  has_many :note_likes, dependent: :destroy

  # --- 校验规则 ---
  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "格式不正确" }

  validates :name, presence: true, length: { maximum: 50 }

  # 密码非直接存库，allow_nil 让「不提密码」的更新也能通过校验
  validates :password, length: { minimum: 6, maximum: 72 }, allow_nil: true

  normalizes :email, with: ->(value) { value.to_s.strip.downcase }
  normalizes :name, with: ->(value) { value.to_s.strip }

  # --- scope ---
  scope :search, ->(keyword) {
    next all if keyword.blank?

    # 转义 % 和 _，避免用户输入被当成 SQL 通配符
    pattern = "%#{sanitize_sql_like(keyword.to_s.strip)}%"
    where("users.email ILIKE :pattern OR users.name ILIKE :pattern", pattern: pattern)
  }

  # --- 业务方法 ---

  # 超管跳过权限校验
  def super_admin?
    role_codes.include?(Role::SUPER_ADMIN_CODE)
  end

  def role_codes
    @role_codes ||= roles.pluck(:code)
  end

  # 只统计启用状态的角色与权限
  def permission_codes
    @permission_codes ||= if super_admin?
      Permission.active.pluck(:code).uniq
    else
      Permission
        .joins(role_permissions: { role: :user_roles })
        .where(user_roles: { user_id: id })
        .where(roles: { status: Role.statuses[:enabled] })
        .where(permissions: { status: Permission.statuses[:enabled] })
        .distinct
        .pluck(:code)
    end
  end

  # 无权限的菜单不会下发到前端
  def menu_permissions
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

  # 改角色后需手动清缓存，否则返回旧值
  def reload_permissions!
    @role_codes = nil
    @permission_codes = nil
    self
  end
end
