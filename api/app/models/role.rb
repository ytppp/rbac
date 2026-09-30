# 角色模型，对应数据库里的 roles 表。
#
# 角色是「用户」和「权限」之间的桥梁：
#   给用户分配角色，而不是一个个勾权限，管理起来更省事。
class Role < ApplicationRecord
  # 内置超管角色标识，拥有该角色的用户跳过权限校验
  SUPER_ADMIN_CODE = "super_admin".freeze

  # 与 User 里同样的 enum 用法：库里存 0/1，代码里用 :disabled / :enabled
  STATUSES = { disabled: 0, enabled: 1 }.freeze

  enum :status, STATUSES, validate: true

  # 中间表关联：一个角色对应多条 user_roles / role_permissions 记录
  has_many :user_roles, dependent: :destroy
  has_many :role_permissions, dependent: :destroy

  # through 拿到「另一端」的对象数组：
  #   role.users        -> 拥有该角色的所有用户
  #   role.permissions  -> 该角色包含的所有权限
  # 另外 permission_ids= / user_ids= 这种批量赋值方法也是靠它生成的，
  # 控制器里「保存角色后重新设置权限」用的就是 role.permission_ids = [...]。
  has_many :users, through: :user_roles
  has_many :permissions, through: :role_permissions

  validates :name, presence: true, length: { maximum: 50 }
  validates :code,
            presence: true,
            uniqueness: { case_sensitive: false },
            # \A 是字符串开头、\z 是字符串结尾（比 ^ $ 更严格）
            # 整体含义：必须以小写字母开头，后面只能是小写字母/数字/下划线，长度 2~50
            format: { with: /\A[a-z][a-z0-9_]{1,49}\z/, message: "只能包含小写字母、数字和下划线，且以字母开头" },
            length: { maximum: 50 }
  validates :description, length: { maximum: 255 }

  scope :search, ->(keyword) {
    next all if keyword.blank?

    pattern = "%#{sanitize_sql_like(keyword.to_s.strip)}%"
    where("roles.name ILIKE :pattern OR roles.code ILIKE :pattern", pattern: pattern)
  }

  def super_admin?
    code == SUPER_ADMIN_CODE
  end

  # 内置角色不允许改 code / 删除。
  # built_in 是数据库里的布尔列，Rails 会自动生成 built_in? 这个方法。
  def code_locked?
    built_in? || super_admin?
  end
end
