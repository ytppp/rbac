# 用户管理的增删改查接口。
#
# 标准 REST 路由（resources :users 生成）：
#   GET    /api/v1/users              列表（index）
#   GET    /api/v1/users/:id          详情（show）
#   POST   /api/v1/users              新增（create）
#   PATCH  /api/v1/users/:id          编辑（update）
#   DELETE /api/v1/users/:id          删除（destroy）
#   PATCH  /api/v1/users/:id/status       启用/禁用（自定义成员路由）
#   PATCH  /api/v1/users/:id/password     重置密码（自定义成员路由）
#
# 每个 action 里都有一句 authorize!("...")，这就是「接口级权限控制」：
# 前端藏起按钮只是体验优化，真正的防线在后端这里。
module Api
  module V1
    class UsersController < BaseController
      # 下面这些 action 都需要先按 id 找到目标用户，统一提前执行 set_user
      before_action :set_user, only: %i[show update destroy status reset_password]
      # 超级管理员账号属于受保护账号，非超管不得改动其任何信息
      before_action :ensure_target_manageable!, only: %i[update destroy status reset_password]

      # GET /api/v1/users
      def index
        authorize!("system:user:list")

        # includes(:roles) 是为了避免「N+1 查询」：不写它会先查 1 次用户，
        # 再为每个用户单独查 1 次角色；写上则提前用少量 SQL 把角色一并取回来。
        scope = User.includes(:roles).search(params[:keyword])
        # 这些 if 都是「前端传了才加这个筛选条件」的可选过滤
        scope = scope.where(status: params[:status]) if params[:status].present?
        if params[:role_id].present?
          # 用子查询找出「拥有该角色」的所有 user_id，再作为条件筛用户
          scope = scope.where(id: UserRole.where(role_id: params[:role_id]).select(:user_id))
        end

        # 注意：scope 一直是「查询条件」而不是「结果数组」，
        # 直到 paginate 里的 .page 才会真正执行 SQL 去查数据库。
        paginated = paginate(scope.order(id: :desc))

        render json: {
          items: UserSerializer.render_collection(paginated),
          meta: pagination_meta(paginated)
        }
      end

      # GET /api/v1/users/:id
      def show
        authorize!("system:user:list")

        render json: UserSerializer.render(@user)
      end

      # POST /api/v1/users
      def create
        authorize!("system:user:create")

        user = User.new(user_params)

        # transaction 表示「事务」：块里的操作要么全部成功，要么全部回滚。
        # 这里「存用户」和「分配角色」必须一起成功，
        # 否则万一分配角色失败，就会留下一个没有任何角色的半成品账号。
        User.transaction do
          # save! 带感叹号：失败时直接抛异常（被 BaseController 接住转成 422），
          # 不带感叹号的 save 只会返回 false，容易漏判。
          user.save!
          user.role_ids = permitted_role_ids if params.key?(:role_ids)
        end

        # reload 重新从数据库读一遍，拿到最新的关联数据再序列化给前端
        render json: UserSerializer.render(user.reload), status: :created
      end

      # PATCH /api/v1/users/:id
      def update
        authorize!("system:user:update")

        User.transaction do
          @user.update!(user_params)
          @user.role_ids = permitted_role_ids if params.key?(:role_ids)
        end

        render json: UserSerializer.render(@user.reload)
      end

      # DELETE /api/v1/users/:id
      def destroy
        authorize!("system:user:delete")

        # 给自己留条后路：不允许删掉自己
        raise ForbiddenError, "不能删除自己" if @user.id == current_user.id

        @user.destroy!
        render json: { message: "删除成功" }
      end

      # PATCH /api/v1/users/:id/status
      def status
        authorize!("system:user:update")

        raise ForbiddenError, "不能禁用自己" if @user.id == current_user.id

        # params.require 表示这个参数必须存在，缺失会抛 ParameterMissing（返回 400）
        @user.update!(status: params.require(:status))
        render json: UserSerializer.render(@user.reload)
      end

      # PATCH /api/v1/users/:id/password  管理员重置密码
      def reset_password
        authorize!("system:user:update")
        # 改自己的密码请走个人中心，那里会校验「当前密码」，这里不校验是为了让管理员能帮别人重置
        raise ForbiddenError, "请到个人中心修改自己的密码" if @user.id == current_user.id

        @user.update!(password_params)
        render json: { message: "密码已重置" }
      end

      private

      # 按路由里的 :id 找出目标用户。
      # find 找不到会抛 RecordNotFound，由 BaseController 统一转成 404。
      def set_user
        @user = User.find(params[:id])
      end

      # 编辑 / 禁用 / 重置密码 / 删除超级管理员账号，只有超级管理员本人可以
      def ensure_target_manageable!
        return if current_user.super_admin?
        return unless @user.super_admin?

        raise ForbiddenError, "超级管理员账号仅超级管理员可操作"
      end

      # params.permit 是 Rails 的「参数白名单」：只有列出来的字段才会被返回，
      # 其它字段（比如前端偷偷多传的 password_digest）会被直接丢弃。
      # 这是防止「批量赋值漏洞」的标准做法。
      def user_params
        permitted = params.permit(:email, :name, :status)
        # 密码这两项单独处理：传了才带上，没传就不出现在参数里，
        # 这样「只改昵称」的请求不会把密码覆盖成空值。
        permitted[:password] = params[:password] if params[:password].present?
        permitted[:password_confirmation] = params[:password_confirmation] if params[:password_confirmation].present?
        permitted
      end

      def password_params
        params.permit(:password, :password_confirmation)
      end

      # 非超级管理员不能把「超级管理员」角色分配给任何人（含自己），否则等于越权提权。
      # Array(...) 保证传入单个值或 nil 时也能安全地转成数组。
      def permitted_role_ids
        ids = Array(params[:role_ids]).map(&:to_i).uniq
        return ids if current_user.super_admin?
        # exists? 只查「有没有」符合条件的记录，比 count 更快
        return ids unless Role.where(id: ids, code: Role::SUPER_ADMIN_CODE).exists?

        raise ForbiddenError, "只有超级管理员可以分配「超级管理员」角色"
      end
    end
  end
end
