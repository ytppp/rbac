# 认证接口：登录、登出、获取当前用户信息。
#
# 路由配置见 config/routes.rb：
#   POST   /api/v1/auth/login
#   DELETE /api/v1/auth/logout
#   GET    /api/v1/auth/me
#
# Rails 约定：控制器里的每个 public 方法叫一个「action」，
# action 名字要和路由里指向的名字一致（to: "auth#login" 就是调用 AuthController#login）。
module Api
  module V1
    class AuthController < BaseController
      # 登录时当然还没有 token，所以必须跳过父类「先登录再访问」的检查。
      # only: :login 表示只对 login 这一个 action 生效，logout / me 仍然需要登录。
      skip_before_action :authenticate_user!, only: :login

      # POST /api/v1/auth/login
      def login
        # 用户输入的邮箱先自己规整一遍再查（和 User 模型里的 normalizes 保持一致的规则）
        user = User.find_by(email: params[:email].to_s.strip.downcase)

        # 用户不存在，或者密码不对，都统一提示「邮箱或密码错误」。
        # 故意不区分「没这个人」和「密码错」，避免被人拿来探测哪些邮箱已注册。
        # authenticate 是 has_secure_password 提供的方法，密码正确返回用户对象，否则返回 false。
        if user.nil? || !user.authenticate(params[:password].to_s)
          return render_error(:unauthorized, "邮箱或密码错误")
        end

        # 密码对了但账号被禁用，也要拦住
        return render_error(:forbidden, "账号已被禁用，请联系管理员") if user.disabled?

        # update_column 会直接更新这一列，不跑校验、也不更新 updated_at
        # （记录登录时间这种小事没必要触发整套校验流程）
        user.update_column(:last_login_at, Time.current)

        render json: {
          # 用 JWT 把 user_id 签名打包成字符串，之后前端每次请求都带上它
          token: JsonWebToken.encode(user.id),
          # 告诉前端这个 token 多少秒后过期，方便到期前自动跳登录页
          expires_in: JsonWebToken.expire_in.to_i,
          user: UserSerializer.render(user),
          # 角色码与权限码一并返回，前端据此控制菜单显隐和按钮禁用
          roles: user.role_codes,
          permissions: user.permission_codes
        }
      end

      # DELETE /api/v1/auth/logout
      def logout
        # JWT 为无状态令牌，登出由前端清除本地 token 完成
        render json: { message: "已退出登录" }
      end

      # GET /api/v1/auth/me
      # 前端刷新页面后用它「用 token 换回当前用户信息」
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
