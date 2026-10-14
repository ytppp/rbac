# 认证接口：登录、登出、获取当前用户信息。
module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: :login

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: params[:email].to_s.strip.downcase)

        # 不区分「用户不存在」和「密码错误」，避免被用来探测已注册邮箱
        if user.nil? || !user.authenticate(params[:password].to_s)
          return render_error(:unauthorized, "邮箱或密码错误")
        end

        return render_error(:forbidden, "账号已被禁用，请联系管理员") if user.disabled?

        user.update_column(:last_login_at, Time.current)

        render json: {
          token: JsonWebToken.encode(user.id),
          expires_in: JsonWebToken.expire_in.to_i,
          user: UserSerializer.render(user),
          roles: user.role_codes,
          permissions: user.permission_codes
        }
      end

      # DELETE /api/v1/auth/logout
      def logout
        # JWT 无状态，登出由前端清除本地 token 完成
        render json: { message: "已退出登录" }
      end

      # GET /api/v1/auth/me
      def me
        render json: {
          user: UserSerializer.render(current_user),
          roles: current_user.role_codes,
          permissions: current_user.permission_codes
        }
      end
    end
  end
end
