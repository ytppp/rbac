# 前端动态菜单 / 路由数据源
#
# 输出的结构正好对应 Vue Router 需要的字段：
#   path      路由地址，如 /system/user
#   component 要加载的组件路径，如 system/user/index
#   children  子路由
# 前端拿到之后自己转换一下，就能 addRoute 注册成动态路由。
class MenuSerializer
  class << self
    # 单个菜单节点。children 先给空数组占位，由下面的 tree 负责填真正的内容。
    def render(menu)
      {
        id: menu.id,
        name: menu.name,
        code: menu.code,
        path: menu.path,
        component: menu.component,
        icon: menu.icon,
        sort: menu.sort,
        children: []
      }
    end

    # 把扁平的 menu 记录组装成嵌套结构。
    # 思路：先按 parent_id 分组，再从「没有父节点」的根节点开始递归往下接。
    def tree(records)
      # 按父节点 id 分组，例如 { nil => [根节点], 5 => [parent_id 为 5 的节点] }
      grouped = records.group_by(&:parent_id)

      build = lambda do |parent_id|
        (grouped[parent_id] || []).map do |record|
          # 递归拿到自己的子节点，合并进 children
          render(record).merge(children: build.call(record.id))
        end
      end

      # 从 nil（根节点）开始，就能得到整棵树
      build.call(nil)
    end
  end
end
