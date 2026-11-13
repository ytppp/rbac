# 认证接口：登录、注册、登出、获取当前用户信息。
module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: %i[login register refresh]
      # 登录 / 注册加限流，避免被撞库或刷注册
      before_action :throttle_login!, only: :login
      before_action :throttle_register!, only: :register
      before_action :throttle_refresh!, only: :refresh

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: params[:email].to_s.strip.downcase)

        # 不区分「用户不存在」和「密码错误」，避免被用来探测已注册邮箱
        if user.nil? || !user.authenticate(params[:password].to_s)
          return render_error(:unauthorized, "邮箱或密码错误")
        end

        return render_error(:forbidden, "账号已被禁用，请联系管理员") if user.disabled?

        user.update_column(:last_login_at, Time.current)

        render json: session_payload(user)
      end

      # POST /api/v1/auth/register
      # 内容社区注册：创建账号并自动分配「注册用户」角色，返回 token 直接登录
      def register
        attributes = params.permit(:name, :email, :password, :password_confirmation)

        name = attributes[:name].to_s.strip
        email = attributes[:email].to_s.strip.downcase
        password = attributes[:password].to_s
        confirmation = attributes[:password_confirmation].to_s

        return render_error(:unprocessable_content, "请填写昵称") if name.blank?
        return render_error(:unprocessable_content, "请填写邮箱") if email.blank?
        return render_error(:unprocessable_content, "邮箱格式不正确") unless email.match?(URI::MailTo::EMAIL_REGEXP)
        return render_error(:unprocessable_content, "昵称最多 50 个字符") if name.length > 50
        return render_error(:unprocessable_content, "密码至少 6 位") if password.length < 6
        return render_error(:unprocessable_content, "两次输入的密码不一致") if password != confirmation
        return render_error(:unprocessable_content, "该邮箱已注册，请直接登录") if User.exists?(email: email)

        role = Role.find_by(code: Role::REGISTERED_USER_CODE)
        return render_error(:unprocessable_content, "注册角色未初始化，请联系管理员") if role.nil?

        user = User.new(name: name, email: email, password: password, password_confirmation: confirmation)
        User.transaction do
          user.save!
          user.roles << role
        end

        # 注册即视为一次登录，方便 app 直接进入已登录状态
        user.update_column(:last_login_at, Time.current)
        user.reload_permissions!

        render json: session_payload(user), status: :created
      rescue ActiveRecord::RecordNotUnique
        # 并发注册同一邮箱时，数据库唯一索引会兜底
        render_error(:unprocessable_content, "该邮箱已注册，请直接登录")
      end

      # DELETE /api/v1/auth/logout
      def logout
        # JWT 无状态，登出由前端清除本地 token 完成
        render json: { message: "已退出登录" }
      end

      # POST /api/v1/auth/refresh
      # 用长效 refresh token 换一对新 token（旧的 refresh token 同时失效）
      def refresh
        payload = JsonWebToken.decode(params[:refresh_token].to_s, type: JsonWebToken::REFRESH_TYPE)
        user = User.find_by(id: payload[:user_id])

        return render_error(:unauthorized, "登录已失效，请重新登录") if user.nil?
        return render_error(:forbidden, "账号已被禁用，请联系管理员") if user.disabled?

        render json: session_payload(user)
      end

      # GET /api/v1/auth/me
      def me
        render json: {
          user: UserSerializer.render(current_user),
          roles: current_user.role_codes,
          permissions: current_user.permission_codes
        }
      end

      private

      def throttle_login!
        throttle!(key: "auth/login", limit: 15, period: 1.minute)
      end

      def throttle_register!
        throttle!(key: "auth/register", limit: 5, period: 10.minutes)
      end

      def throttle_refresh!
        throttle!(key: "auth/refresh", limit: 20, period: 1.minute)
      end

      def session_payload(user)
        {
          access_token: JsonWebToken.encode_access(user.id),
          refresh_token: JsonWebToken.encode_refresh(user.id),
          token_type: "Bearer",
          expires_in: JsonWebToken.access_expire_in.to_i,
          user: UserSerializer.render(user),
          roles: user.role_codes,
          permissions: user.permission_codes
        }
      end
    end
  end
end
