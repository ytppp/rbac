# 角色管理接口。
module Api
  module V1
    class RolesController < BaseController
      before_action :set_role, only: %i[show update destroy]

      def index
        authorize!("system:role:list")

        scope = Role.search(params[:keyword])
        scope = scope.where(status: params[:status]) if params[:status].present?

        paginated = paginate(scope.order(id: :asc))

        counts = UserRole.where(role_id: paginated.map(&:id)).group(:role_id).count

        render json: {
          items: paginated.map { |role|
            RoleSerializer.render(role, include_permissions: false, user_count: counts[role.id] || 0)
          },
          meta: pagination_meta(paginated)
        }
      end

      # GET /api/v1/roles/options  下拉选项（用户管理分配角色时使用）
      def options
        authorize_any!("system:role:list", "system:user:list")

        roles = Role.where(status: Role.statuses[:enabled]).order(:id)
        # 非超管不能看到「超级管理员」选项，避免越权提权
        roles = roles.where.not(code: Role::SUPER_ADMIN_CODE) unless current_user.super_admin?

        render json: { items: roles.map { |role| RoleSerializer.render_option(role) } }
      end

      def show
        authorize!("system:role:list")

        render json: RoleSerializer.render(@role, user_count: @role.users.count)
      end

      def create
        authorize!("system:role:create")

        role = Role.new(role_params)

        Role.transaction do
          role.save!
          role.permission_ids = permitted_permission_ids if params.key?(:permission_ids)
        end

        render json: RoleSerializer.render(role.reload, user_count: 0), status: :created
      end

      def update
        authorize!("system:role:update")

        # 内置角色不允许修改 code
        raise ForbiddenError, "内置角色不允许修改编码" if @role.code_locked? && role_params[:code].present? &&
                                                        role_params[:code] != @role.code

        Role.transaction do
          @role.update!(role_params)
          @role.permission_ids = permitted_permission_ids if params.key?(:permission_ids)
        end

        render json: RoleSerializer.render(@role.reload, user_count: @role.users.count)
      end

      def destroy
        authorize!("system:role:delete")

        raise ForbiddenError, "内置角色不允许删除" if @role.code_locked?
        raise ForbiddenError, "该角色下仍有用户，请先解除关联" if @role.user_roles.exists?

        @role.destroy!
        render json: { message: "删除成功" }
      end

      private

      def set_role
        @role = Role.find(params[:id])
      end

      # 白名单不含 :built_in，内置标记不允许通过接口修改
      def role_params
        params.permit(:name, :code, :description, :status)
      end

      def permitted_permission_ids
        Array(params[:permission_ids]).map(&:to_i).uniq
      end
    end
  end
end
