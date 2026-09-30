# 角色管理的接口。整体结构和 UsersController 几乎一样，可以对照着看。
#
# 角色比用户多了一层「权限关联」：保存角色后，还要把 role.permission_ids 重设一遍。
module Api
  module V1
    class RolesController < BaseController
      before_action :set_role, only: %i[show update destroy]

      # GET /api/v1/roles
      def index
        authorize!("system:role:list")

        scope = Role.search(params[:keyword])
        scope = scope.where(status: params[:status]) if params[:status].present?

        paginated = paginate(scope.order(id: :asc))

        # 列表里要显示「每个角色下有几个人」。
        # 如果循环里逐个 role.users.count，10 条数据就要查 10 次库（N+1）。
        # 这里用一条分组统计 SQL 一次性拿到所有结果：
        #   { 角色id => 人数 }，例如 { 1 => 2, 3 => 0 }
        # map(&:id) 是「对数组每个元素调用 .id」的简写。
        counts = UserRole.where(role_id: paginated.map(&:id)).group(:role_id).count

        render json: {
          items: paginated.map { |role|
            # include_permissions: false —— 列表页不需要每个角色的完整权限 id 列表，省点数据量
            RoleSerializer.render(role, include_permissions: false, user_count: counts[role.id] || 0)
          },
          meta: pagination_meta(paginated)
        }
      end

      # GET /api/v1/roles/options  下拉选项（用户管理分配角色时使用）
      def options
        # 这里用 any 而不是 all：不管是管角色的还是管用户的，都需要这份下拉数据
        authorize_any!("system:role:list", "system:user:list")

        roles = Role.where(status: Role.statuses[:enabled]).order(:id)
        # 非超管看不到「超级管理员」选项，避免其通过分配角色把自己或他人提权
        roles = roles.where.not(code: Role::SUPER_ADMIN_CODE) unless current_user.super_admin?

        render json: { items: roles.map { |role| RoleSerializer.render_option(role) } }
      end

      # GET /api/v1/roles/:id
      def show
        authorize!("system:role:list")

        # 详情页需要完整权限 id，所以这里不传 include_permissions: false
        render json: RoleSerializer.render(@role, user_count: @role.users.count)
      end

      # POST /api/v1/roles
      def create
        authorize!("system:role:create")

        role = Role.new(role_params)

        # 和创建用户同理：角色本身和它的权限关联必须一起成功
        Role.transaction do
          role.save!
          role.permission_ids = permitted_permission_ids if params.key?(:permission_ids)
        end

        render json: RoleSerializer.render(role.reload, user_count: 0), status: :created
      end

      # PATCH /api/v1/roles/:id
      def update
        authorize!("system:role:update")

        # code_locked? 是 Role 模型里定义的方法（内置角色或超管角色返回 true）。
        # 这行在拦「想把内置角色的 code 改掉」的请求：
        # 传了 code、且和原值不同，才报错；不传或传一样的值都放行。
        raise ForbiddenError, "内置角色不允许修改编码" if @role.code_locked? && role_params[:code].present? &&
                                                        role_params[:code] != @role.code

        Role.transaction do
          @role.update!(role_params)
          @role.permission_ids = permitted_permission_ids if params.key?(:permission_ids)
        end

        render json: RoleSerializer.render(@role.reload, user_count: @role.users.count)
      end

      # DELETE /api/v1/roles/:id
      def destroy
        authorize!("system:role:delete")

        raise ForbiddenError, "内置角色不允许删除" if @role.code_locked?
        # user_roles.exists? 判断「还有没有用户挂在它下面」，有就不让删
        raise ForbiddenError, "该角色下仍有用户，请先解除关联" if @role.user_roles.exists?

        @role.destroy!
        render json: { message: "删除成功" }
      end

      private

      def set_role
        @role = Role.find(params[:id])
      end

      # 参数白名单。注意这里没有 :built_in —— 内置标记不允许通过接口修改。
      def role_params
        params.permit(:name, :code, :description, :status)
      end

      def permitted_permission_ids
        Array(params[:permission_ids]).map(&:to_i).uniq
      end
    end
  end
end
