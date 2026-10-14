# 权限模型，对应 permissions 表。menu/button 两种形态，并自关联成树。
class Permission < ApplicationRecord
  # type 是业务字段（菜单/按钮），关闭 STI 继承列，否则 Rails 会当成子类名报错
  self.inheritance_column = nil

  TYPES = { menu: 0, button: 1 }.freeze
  STATUSES = { disabled: 0, enabled: 1 }.freeze

  enum :type, TYPES, validate: true
  enum :status, STATUSES, validate: true

  # --- 自关联 ---
  belongs_to :parent, class_name: "Permission", optional: true, inverse_of: :children

  # 下面还有子节点时不允许删除
  has_many :children, class_name: "Permission", dependent: :restrict_with_error,
                      inverse_of: :parent, foreign_key: :parent_id

  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions

  validates :name, presence: true, length: { maximum: 50 }
  validates :code,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: /\A[a-z][a-z0-9_]*(:{1,2}[a-z0-9_]+)*\z/,
                      message: "只能使用小写字母、数字、下划线和冒号，且以字母开头" },
            length: { maximum: 100 }
  validates :sort, numericality: { only_integer: true }
  validates :path, presence: true, if: :menu?

  validate :parent_must_be_menu_node
  validate :parent_must_not_be_descendant

  # --- scope ---
  scope :active, -> { where(status: STATUSES[:enabled]) }
  scope :menus, -> { where(type: TYPES[:menu]) }
  scope :buttons, -> { where(type: TYPES[:button]) }
  scope :sorted, -> { order(:sort, :id) }
  scope :search, ->(keyword) {
    next all if keyword.blank?

    pattern = "%#{sanitize_sql_like(keyword.to_s.strip)}%"
    where("permissions.name ILIKE :pattern OR permissions.code ILIKE :pattern", pattern: pattern)
  }

  class << self
    def tree(records = sorted)
      grouped = records.to_a.group_by(&:parent_id)

      build = lambda do |parent_id|
        (grouped[parent_id] || []).map do |node|
          node.as_tree_node.merge(children: build.call(node.id))
        end
      end

      build.call(nil)
    end
  end

  def as_tree_node
    {
      id: id,
      name: name,
      code: code,
      # enum 读取器返回字符串，这里统一转成 0/1 给前端
      type: menu? ? 0 : 1,
      type_text: menu? ? "菜单" : "按钮",
      parent_id: parent_id,
      path: path,
      component: component,
      icon: icon,
      sort: sort,
      status: enabled? ? 1 : 0,
      status_text: enabled? ? "启用" : "禁用"
    }
  end

  # 自身 + 所有后代的 id，用于防止把节点挂到自己的子孙下面
  def descendant_ids
    result = [id]
    queue = [id]

    until queue.empty?
      child_ids = self.class.where(parent_id: queue.shift).pluck(:id)
      result.concat(child_ids)
      queue.concat(child_ids)
    end

    result
  end

  private

  def parent_must_be_menu_node
    return if parent_id.blank? || parent&.menu?

    errors.add(:parent_id, "只能选择菜单类型的节点作为上级")
  end

  def parent_must_not_be_descendant
    return if parent_id.blank? || new_record?
    return unless descendant_ids.include?(parent_id)

    errors.add(:parent_id, "不能选择自身或其子节点作为上级")
  end
end
