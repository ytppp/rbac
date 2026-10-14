# 角色模型，对应 roles 表。
class Role < ApplicationRecord
  # 超管角色标识，拥有该角色的用户跳过权限校验
  SUPER_ADMIN_CODE = "super_admin".freeze

  STATUSES = { disabled: 0, enabled: 1 }.freeze

  enum :status, STATUSES, validate: true

  has_many :user_roles, dependent: :destroy
  has_many :role_permissions, dependent: :destroy

  has_many :users, through: :user_roles
  has_many :permissions, through: :role_permissions

  validates :name, presence: true, length: { maximum: 50 }
  validates :code,
            presence: true,
            uniqueness: { case_sensitive: false },
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

  # 内置角色不允许改 code / 删除
  def code_locked?
    built_in? || super_admin?
  end
end
