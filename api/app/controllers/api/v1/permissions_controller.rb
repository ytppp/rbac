# 权限（菜单 / 按钮）管理的接口。
module Api
  module V1
    class PermissionsController < BaseController
      before_action :set_permission, only: %i[show update destroy]

      # 默认返回树形结构；flat=true 或带关键字搜索时返回扁平列表
      def index
        authorize!("system:permission:list")

        scope = Permission.search(params[:keyword])
        scope = scope.where(type: params[:type]) if params[:type].present?
        scope = scope.where(status: params[:status]) if params[:status].present?

        records = scope.sorted

        # 搜索命中往往是零散子节点，拼树会丢父节点，故搜索时返回扁平列表
        flat = params[:flat].to_s == "true" || params[:keyword].present?
        items = flat ? PermissionSerializer.render_collection(records) : Permission.tree(records)

        render json: { items: items }
      end

      # GET /api/v1/permissions/options  上级菜单下拉数据
      def options
        authorize_any!("system:permission:list", "system:role:list")

        # 只有「菜单」能当上级，按钮不能有下级
        menus = Permission.menus.sorted
        render json: { items: menus.map { |permission| PermissionSerializer.render_option(permission) } }
      end

      def show
        authorize!("system:permission:list")

        render json: PermissionSerializer.render(@permission)
      end

      def create
        authorize!("system:permission:create")

        permission = Permission.new(permission_params)
        permission.save!

        render json: PermissionSerializer.render(permission), status: :created
      end

      def update
        authorize!("system:permission:update")

        @permission.update!(permission_params)
        render json: PermissionSerializer.render(@permission)
      end

      def destroy
        authorize!("system:permission:delete")

        raise ForbiddenError, "请先删除该节点下的子节点" if @permission.children.exists?
        raise ForbiddenError, "该权限已分配给角色，请先在角色中解除关联" if @permission.role_permissions.exists?

        @permission.destroy!
        render json: { message: "删除成功" }
      end

      private

      def set_permission
        @permission = Permission.find(params[:id])
      end

      def permission_params
        params.permit(:name, :code, :type, :parent_id, :path, :component, :icon, :sort, :status)
      end
    end
  end
end
