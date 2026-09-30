# 权限（菜单 / 按钮）管理的接口。
#
# 和用户、角色最大的不同：权限是一条条挂在树上展示的，
# 所以 index 默认返回树形结构，而搜索时返回扁平列表。
module Api
  module V1
    class PermissionsController < BaseController
      before_action :set_permission, only: %i[show update destroy]

      # GET /api/v1/permissions
      # 默认返回树形结构；flat=true 或带关键字搜索时返回扁平列表
      def index
        authorize!("system:permission:list")

        scope = Permission.search(params[:keyword])
        scope = scope.where(type: params[:type]) if params[:type].present?
        scope = scope.where(status: params[:status]) if params[:status].present?

        records = scope.sorted

        # 为什么搜索时要改成扁平列表？
        # 因为搜索出来的结果往往只命中树里的某几个子节点，
        # 强行拼成树会丢掉父节点、结构不完整，不如直接平铺展示。
        flat = params[:flat].to_s == "true" || params[:keyword].present?
        items = flat ? PermissionSerializer.render_collection(records) : Permission.tree(records)

        # 注意这里没有分页：权限总数量很少，前端一屏树会全部用到
        render json: { items: items }
      end

      # GET /api/v1/permissions/options  上级菜单下拉数据
      def options
        # 新建权限时选上级、给角色配权限时都要用，所以两个权限都放行
        authorize_any!("system:permission:list", "system:role:list")

        # 只有「菜单」能当上级（按钮不能有下级），相关规则见 Permission 模型的校验
        menus = Permission.menus.sorted
        render json: { items: menus.map { |permission| PermissionSerializer.render_option(permission) } }
      end

      # GET /api/v1/permissions/:id
      def show
        authorize!("system:permission:list")

        render json: PermissionSerializer.render(@permission)
      end

      # POST /api/v1/permissions
      def create
        authorize!("system:permission:create")

        permission = Permission.new(permission_params)
        # 这里没有用 transaction，因为只涉及「存一条记录」这一件事，不需要原子性保证
        permission.save!

        render json: PermissionSerializer.render(permission), status: :created
      end

      # PATCH /api/v1/permissions/:id
      def update
        authorize!("system:permission:update")

        @permission.update!(permission_params)
        render json: PermissionSerializer.render(@permission)
      end

      # DELETE /api/v1/permissions/:id
      def destroy
        authorize!("system:permission:delete")

        # 这两条拦截对应模型里的两种关联约束，提前给出更友好的中文提示
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
