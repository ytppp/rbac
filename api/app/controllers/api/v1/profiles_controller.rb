# 个人中心接口：任何已登录用户都能操作「自己」，不需要额外权限（所以没有 authorize!）。
#
# 和 UsersController 的区别：
#   UsersController  -> 管理员管理「别人」，需要 system:user:* 权限
#   ProfilesController -> 所有人管理「自己」，只要登录就行
#
# 路由里写的是 resource（单数），因为「自己」只有一份，不需要 :id：
#   GET   /api/v1/profile
#   PATCH /api/v1/profile
#   PATCH /api/v1/profile/password
module Api
  module V1
    class ProfilesController < BaseController
      # GET /api/v1/profile
      def show
        render json: {
          user: UserSerializer.render(current_user),
          # 这里单独拼了简版角色信息，因为个人中心只需要展示名字，不需要完整字段
          # 块里最后一行表达式的值会被自动返回（Ruby 方法默认返回最后一行）
          roles: current_user.roles.map { |role| { id: role.id, name: role.name, code: role.code } },
          permissions: current_user.permission_codes
        }
      end

      # PATCH /api/v1/profile
      def update
        # 直接改 current_user，不会存在「改到别人头上」的风险
        current_user.update!(profile_params)
        render json: UserSerializer.render(current_user.reload)
      end

      # PATCH /api/v1/profile/password
      def password
        # 改自己的密码必须先验证「当前密码」，防止电脑被人顺手改掉密码
        unless current_user.authenticate(params[:current_password].to_s)
          # 第三个参数是 details，前端可以按字段名把错误提示显示在对应输入框下面
          return render_error(:unprocessable_entity, "当前密码不正确", current_password: ["当前密码不正确"])
        end

        if params[:password].to_s != params[:password_confirmation].to_s
          return render_error(:unprocessable_entity, "两次输入的新密码不一致",
                              password_confirmation: ["两次输入的新密码不一致"])
        end

        current_user.update!(password: params[:password], password_confirmation: params[:password_confirmation])
        render json: { message: "密码修改成功，请重新登录" }
      end

      private

      # 注意白名单里只有 name 和 email，没有 password、也没有 status：
      # 个人中心不允许自己改密码（走上面的 password）、更不允许自己改启用状态。
      def profile_params
        params.permit(:name, :email)
      end
    end
  end
end
