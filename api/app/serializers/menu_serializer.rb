# 前端动态菜单 / 路由数据源。
class MenuSerializer
  class << self
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

    def tree(records)
      grouped = records.group_by(&:parent_id)

      build = lambda do |parent_id|
        (grouped[parent_id] || []).map do |record|
          render(record).merge(children: build.call(record.id))
        end
      end

      build.call(nil)
    end
  end
end
