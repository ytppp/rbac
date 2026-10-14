# 菜单接口：返回当前登录用户有权访问的菜单树，供前端生成动态路由与侧边栏。
module Api
  module V1
    class MenusController < BaseController
      # 无 authorize!：菜单本就该按人返回，登录后即可拿到属于自己的那份
      def index
        render json: { items: MenuSerializer.tree(current_user.menu_permissions.to_a) }
      end
    end
  end
end
