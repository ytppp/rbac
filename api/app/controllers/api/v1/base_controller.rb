# 所有 V1 接口控制器的父类，集中存放认证、授权、分页与统一错误响应等公共逻辑。
module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_user!

      rescue_from AuthError, with: :render_unauthorized
      rescue_from ForbiddenError, with: :render_forbidden
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::RecordNotDestroyed, with: :render_record_not_destroyed
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

      private

      attr_reader :current_user

      # ---------- 认证 ----------

      def authenticate_user!
        raise AuthError, "未登录,请先登录" if bearer_token.blank?

        payload = JsonWebToken.decode(bearer_token)
        @current_user = User.find_by(id: payload[:user_id])

        raise AuthError, "账号不存在，请重新登录" if @current_user.nil?
        # 已禁用的账号即使 token 未过期也不允许访问
        raise AuthError, "账号已被禁用，请联系管理员" if @current_user.disabled?
      end

      def bearer_token
        header = request.headers["Authorization"].to_s
        return nil unless header.start_with?("Bearer ")

        header.split(" ", 2).last.presence
      end

      # 可选认证：带了有效 token 就识别用户，没带或无效也不报错
      def optional_authenticate_user!
        return if bearer_token.blank?

        payload = JsonWebToken.decode(bearer_token)
        @current_user = User.find_by(id: payload[:user_id])
        @current_user = nil if @current_user&.disabled?
      rescue AuthError
        @current_user = nil
      end

      # ---------- 授权 ----------

      def authorize!(*codes)
        return true if current_user.super_admin?
        return true if codes.all? { |code| granted_codes.include?(code) }

        raise ForbiddenError, "无权限执行该操作（需要权限：#{codes.join(' 或 ')}）"
      end

      def authorize_any!(*codes)
        return true if current_user.super_admin?
        return true if codes.any? { |code| granted_codes.include?(code) }

        raise ForbiddenError, "无权限执行该操作（需要权限：#{codes.join(' 或 ')}）"
      end

      # 当前用户拥有的权限码集合（同一请求内记忆化，只查一次库）
      def granted_codes
        @granted_codes ||= current_user.permission_codes
      end

      # ---------- 分页 ----------

      # 页码至少为 1
      def page
        [params[:page].to_i, 1].max
      end

      # 每页条数默认 10，上限 100，防止一次拉走整张表
      def per_page
        value = params[:per_page].to_i
        return 10 if value <= 0

        [value, 100].min
      end

      def paginate(scope)
        scope.page(page).per(per_page)
      end

      def pagination_meta(paginated)
        {
          page: paginated.current_page,
          per_page: paginated.limit_value,
          total: paginated.total_count,
          total_pages: paginated.total_pages
        }
      end

      # ---------- 统一错误响应 ----------

      # 所有错误统一为 { error:, details: } 结构，details 仅在需要时附加
      def render_error(status, message, details = nil)
        body = { error: message }
        body[:details] = details if details.present?
        render json: body, status: status
      end

      def render_unauthorized(exception)
        render_error(:unauthorized, exception.message)
      end

      def render_forbidden(exception)
        render_error(:forbidden, exception.message)
      end

      def render_not_found(exception)
        render_error(:not_found, "记录不存在或已被删除", exception.message)
      end

      def render_record_invalid(exception)
        render_error(:unprocessable_entity, "数据校验失败", exception.record.errors.to_hash)
      end

      def render_record_not_destroyed(exception)
        render_error(:unprocessable_entity, exception.record.errors.full_messages.join("；"))
      end

      def render_parameter_missing(exception)
        render_error(:bad_request, "缺少必要参数：#{exception.param}")
      end
    end
  end
end
