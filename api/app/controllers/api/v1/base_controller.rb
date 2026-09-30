# 所有 V1 接口控制器的「父类」，把公共逻辑集中放在这里，子类只写自己的业务。
#
# 三个目录层级构成了类名的全称：
#   app/controllers/api/v1/base_controller.rb
#   -> module Api / module V1 / class BaseController
# Ruby 里模块负责「分组命名」，所以这个类的完整名字是 Api::V1::BaseController。
module Api
  module V1
    class BaseController < ActionController::API
      # before_action 声明「每个 action 执行前都先跑这个方法」。
      # 子类可以用 skip_before_action 跳过它（比如登录接口、公开的内容接口）。
      before_action :authenticate_user!

      # rescue_from 是「全局兜底」：代码里任何地方抛出这些异常，
      # 都会被对应的 render_xxx 方法接住，转成统一的 JSON 响应，
      # 这样控制器里就不必到处写 begin/rescue。
      rescue_from AuthError, with: :render_unauthorized
      rescue_from ForbiddenError, with: :render_forbidden
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::RecordNotDestroyed, with: :render_record_not_destroyed
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

      private

      # attr_reader 是 Ruby 简写，等价于定义了一个只读方法：
      #   def current_user; @current_user; end
      # 于是子类控制器里可以直接写 current_user。
      attr_reader :current_user

      # ---------- 认证：你是谁？ ----------

      # 从请求头里的 token 解析出当前登录用户；解析不成功就抛 AuthError（被上面的 rescue_from 接住）。
      def authenticate_user!
        raise AuthError, "未登录,请先登录" if bearer_token.blank?

        # 解析 JWT，拿到里面存的 user_id，再去数据库找这个人
        payload = JsonWebToken.decode(bearer_token)
        @current_user = User.find_by(id: payload[:user_id])

        raise AuthError, "账号不存在，请重新登录" if @current_user.nil?
        # 已被禁用的账号即使 token 还没过期，也不允许继续访问
        raise AuthError, "账号已被禁用，请联系管理员" if @current_user.disabled?
      end

      # 从 "Authorization: Bearer xxx.yyy.zzz" 这个请求头里取出 token 部分
      def bearer_token
        header = request.headers["Authorization"].to_s
        return nil unless header.start_with?("Bearer ")

        # split(" ", 2) 只按第一个空格切一次，最后一段就是 token
        # .presence 是 Rails 的方法：空字符串会被转成 nil，让上层用 blank? 判断更统一
        header.split(" ", 2).last.presence
      end

      # ---------- 授权：你能干什么？ ----------

      # 要求「同时拥有」传入的所有权限码，例如 authorize!("system:user:list", "system:user:update")
      def authorize!(*codes)
        # 超管直接放行，不做任何权限校验
        return true if current_user.super_admin?
        # all? 要求数组里每一项都满足条件
        return true if codes.all? { |code| granted_codes.include?(code) }

        raise ForbiddenError, "无权限执行该操作（需要权限：#{codes.join(' 或 ')}）"
      end

      # 要求「拥有其中任意一个」权限码即可
      def authorize_any!(*codes)
        return true if current_user.super_admin?
        # any? 只要有一项满足就返回 true
        return true if codes.any? { |code| granted_codes.include?(code) }

        raise ForbiddenError, "无权限执行该操作（需要权限：#{codes.join(' 或 ')}）"
      end

      # 当前用户拥有的权限码集合。
      # 同样用了记忆化：一个请求里可能调用多次授权判断，但只查一次库。
      def granted_codes
        @granted_codes ||= current_user.permission_codes
      end

      # ---------- 分页 ----------

      # 页码：至少为 1（用户传 0 或负数都当成第 1 页）
      def page
        [params[:page].to_i, 1].max
      end

      # 每页条数：默认 10；用户传超过 100 就按 100 算，防止一次拉走整张表
      def per_page
        value = params[:per_page].to_i
        return 10 if value <= 0

        [value, 100].min
      end

      # 把查询对象交给 Kaminari 这个 gem 做分页，返回带分页信息的对象
      def paginate(scope)
        scope.page(page).per(per_page)
      end

      # 统一的分页响应结构，前端据此渲染分页器
      def pagination_meta(paginated)
        {
          page: paginated.current_page,
          per_page: paginated.limit_value,
          total: paginated.total_count,
          total_pages: paginated.total_pages
        }
      end

      # ---------- 统一错误响应 ----------

      # 所有错误都长成 { "error": "提示文案" } 的形状，details 只在需要时附加（比如字段级校验错误）
      def render_error(status, message, details = nil)
        body = { error: message }
        body[:details] = details if details.present?
        # render json: 把 Hash 转成 JSON 输出，status: 指定 HTTP 状态码
        render json: body, status: status
      end

      # 下面是上面 rescue_from 指向的处理方法，参数就是被捕获的那个异常对象
      def render_unauthorized(exception)
        render_error(:unauthorized, exception.message)   # 401
      end

      def render_forbidden(exception)
        render_error(:forbidden, exception.message)      # 403
      end

      def render_not_found(exception)
        render_error(:not_found, "记录不存在或已被删除", exception.message)  # 404
      end

      def render_record_invalid(exception)
        # exception.record 是保存失败的那个对象，errors.to_hash 拿到「字段 => 错误信息数组」
        render_error(:unprocessable_entity, "数据校验失败", exception.record.errors.to_hash)  # 422
      end

      def render_record_not_destroyed(exception)
        render_error(:unprocessable_entity, exception.record.errors.full_messages.join("；"))
      end

      def render_parameter_missing(exception)
        render_error(:bad_request, "缺少必要参数：#{exception.param}")   # 400
      end
    end
  end
end
