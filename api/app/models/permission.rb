# 权限模型，对应数据库里的 permissions 表。
#
# 这里的「权限」有两种形态，都放在同一张表里，用 type 列区分：
#   type = 0 (menu)   菜单权限 —— 决定前端能不能看到某个页面/菜单项
#   type = 1 (button) 按钮权限 —— 决定前端某个按钮是否可点，同时也是后端接口的校验依据
#
# 表里还有 parent_id 指向自己，所以它是一棵自关联的树：
#   系统管理 -> 用户管理 -> 查询用户 / 新增用户 ...
class Permission < ApplicationRecord
  # Rails 有个老特性叫 STI（单表继承）：如果表里有个叫 type 的列，
  # Rails 会默认把它当成「这一行属于哪个子类」来用（比如 type = "AdminUser"）。
  # 我们这里的 type 只是普通的业务字段（菜单/按钮），所以必须关掉继承列，否则会报类找不到的错。
  self.inheritance_column = nil

  TYPES = { menu: 0, button: 1 }.freeze
  STATUSES = { disabled: 0, enabled: 1 }.freeze

  enum :type, TYPES, validate: true
  enum :status, STATUSES, validate: true

  # --- 自关联：自己指向自己，形成一棵树 ---
  # belongs_to 的默认类名会从关联名（:parent）推导，这里类名是 Permission，所以必须显式指定。
  # optional: true 表示 parent_id 可以为空（根节点没有上级）。
  belongs_to :parent, class_name: "Permission", optional: true, inverse_of: :children

  # dependent: :restrict_with_error 表示「下面还有子节点时不允许删除」，
  # 删除会失败并在对象的 errors 里写入原因（控制器据此返回友好提示）。
  # inverse_of 告诉 Rails 这两头是同一个关联，foreign_key 指明用 parent_id 这一列来连。
  has_many :children, class_name: "Permission", dependent: :restrict_with_error,
                      inverse_of: :parent, foreign_key: :parent_id

  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions

  validates :name, presence: true, length: { maximum: 50 }
  validates :code,
            presence: true,
            uniqueness: { case_sensitive: false },
            # 权限码形如 system:user:create，用冒号分层
            # 拆开看：以小写字母开头 + 若干小写字母/数字/下划线，后面可以再跟 :xxx 这样的若干段
            format: { with: /\A[a-z][a-z0-9_]*(:{1,2}[a-z0-9_]+)*\z/,
                      message: "只能使用小写字母、数字、下划线和冒号，且以字母开头" },
            length: { maximum: 100 }
  validates :sort, numericality: { only_integer: true }
  # if: :menu? 表示这条校验只在「菜单类型」的记录上生效。
  # 菜单必须有前端路由地址；component 留空表示该节点只是目录，前端用 ParentView 包裹。
  validates :path, presence: true, if: :menu?

  # 下面两个是自定义校验方法（定义在文件底部的 private 区域），
  # Rails 会调用同名实例方法来判断是否合法。
  validate :parent_must_be_menu_node
  validate :parent_must_not_be_descendant

  # --- scope ---
  # 这些短名字让控制器里的代码更像自然语言：Permission.active.menus.sorted
  scope :active, -> { where(status: STATUSES[:enabled]) }
  scope :menus, -> { where(type: TYPES[:menu]) }
  scope :buttons, -> { where(type: TYPES[:button]) }
  # order(:sort, :id) 等价于「先按 sort 升序，sort 相同时按 id 升序」
  scope :sorted, -> { order(:sort, :id) }
  scope :search, ->(keyword) {
    next all if keyword.blank?

    pattern = "%#{sanitize_sql_like(keyword.to_s.strip)}%"
    where("permissions.name ILIKE :pattern OR permissions.code ILIKE :pattern", pattern: pattern)
  }

  # class << self ... end 是 Ruby 打开「类方法区」的写法，
  # 写在里面的方法都用 Permission.tree(...) 这样调用。
  class << self
    # 把扁平的记录列表组装成树形结构（树节点同样需要 type_text / status_text，前端表格直接展示）
    def tree(records = sorted)
      # group_by(&:parent_id) 把记录按父节点分组：
      #   { nil => [根节点们], 2 => [parent_id 是 2 的子节点们], ... }
      # group_by(&:parent_id) 里的 &: 是 Ruby 的简写，等价于 { |r| r.parent_id }
      grouped = records.to_a.group_by(&:parent_id)

      # lambda 是一个「可以反复调用的代码块」，这里用来递归。
      # build 接收一个 parent_id，返回它下面所有子节点的树形数组。
      build = lambda do |parent_id|
        (grouped[parent_id] || []).map do |node|
          # as_tree_node 拿到自己的字段，再 merge 上递归出来的 children
          node.as_tree_node.merge(children: build.call(node.id))
        end
      end

      # 从「没有父节点」开始递归，就能拿到整棵树
      build.call(nil)
    end
  end

  # 转成前端要的扁平字段格式（序列化器会直接复用它）
  def as_tree_node
    {
      id: id,
      name: name,
      code: code,
      # 注意：Rails 7 的 enum 读取器返回字符串（"menu"/"enabled"），这里统一转成 0/1 给前端
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

  # 自身 + 所有后代的 id，用于防止「把节点挂到自己的子孙下面」这种会造成环的操作。
  # 这里用的是广度优先遍历：queue 存待处理的节点 id，一个个取出来找它的子节点，
  # 找到的子节点既加入结果、也加入队列继续往下找，直到队列空。
  def descendant_ids
    result = [id]
    queue = [id]

    until queue.empty?
      child_ids = self.class.where(parent_id: queue.shift).pluck(:id)
      result.concat(child_ids)   # concat 把数组拼接到 result 末尾
      queue.concat(child_ids)
    end

    result
  end

  # private 下面的方法不能被外部对象调用，只能在类内部用
  private

  def parent_must_be_menu_node
    # 没有上级（根节点）直接通过
    return if parent_id.blank? || parent&.menu?
    # &. 是 Ruby 的「安全调用」：parent 为 nil 时整体返回 nil，不会报错

    errors.add(:parent_id, "只能选择菜单类型的节点作为上级")
  end

  def parent_must_not_be_descendant
    return if parent_id.blank? || new_record?   # 新建记录还没有子节点，不用检查
    return unless descendant_ids.include?(parent_id)

    errors.add(:parent_id, "不能选择自身或其子节点作为上级")
  end
end
