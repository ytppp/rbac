# 个人中心接口：任何已登录用户都能操作「自己」，无需额外权限。
module Api
  module V1
    class ProfilesController < BaseController
      def show
        render json: {
          user: UserSerializer.render(current_user),
          roles: current_user.roles.map { |role| { id: role.id, name: role.name, code: role.code } },
          permissions: current_user.permission_codes
        }
      end

      def update
        current_user.update!(profile_params)
        render json: UserSerializer.render(current_user.reload)
      end

      # PATCH /api/v1/profile/password
      def password
        # 改自己的密码必须先验证当前密码
        unless current_user.authenticate(params[:current_password].to_s)
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

      # 白名单只有 name 和 email：不允许改密码和启用状态
      def profile_params
        params.permit(:name, :email)
      end
    end
  end
end
