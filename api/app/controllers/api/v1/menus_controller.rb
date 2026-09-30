# 菜单接口 —— 前端动态路由的数据源。
#
# 这是整个 RBAC 里最直观的一个接口：
# 登录后前端调它拿到「当前用户有权访问的菜单树」，
# 然后据此生成路由表和侧边栏。没有权限的菜单根本不会下发给前端。
module Api
  module V1
    class MenusController < BaseController
      # GET /api/v1/menus
      # 返回当前登录用户有权访问的菜单树，前端据此生成动态路由与侧边栏
      #
      # 这里没有 authorize! 调用，原因是：
      # 「能看到哪些菜单」本身就该按人返回，不需要额外再设一道权限门槛，
      # 只要登录了（父类的 authenticate_user! 已保证）就能拿到属于自己的那份菜单。
      def index
        # current_user 来自 BaseController 的 attr_reader
        # menu_permissions 是 User 模型里的方法，已经过滤掉禁用项并按 sort 排好序
        # MenuSerializer.tree 把扁平数组拼成 { ..., children: [...] } 的嵌套结构
        # .to_a 是为了把查询结果真正转成数组（序列化器内部对它做了 group_by 分组）
        render json: { items: MenuSerializer.tree(current_user.menu_permissions.to_a) }
      end
    end
  end
end
