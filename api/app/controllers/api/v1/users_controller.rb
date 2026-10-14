# 用户管理接口（增删改查）。
module Api
  module V1
    class UsersController < BaseController
      before_action :set_user, only: %i[show update destroy status reset_password]
      # 超级管理员账号受保护，非超管不得改动其任何信息
      before_action :ensure_target_manageable!, only: %i[update destroy status reset_password]

      def index
        authorize!("system:user:list")

        scope = User.includes(:roles).search(params[:keyword])
        scope = scope.where(status: params[:status]) if params[:status].present?
        if params[:role_id].present?
          scope = scope.where(id: UserRole.where(role_id: params[:role_id]).select(:user_id))
        end

        paginated = paginate(scope.order(id: :desc))

        render json: {
          items: UserSerializer.render_collection(paginated),
          meta: pagination_meta(paginated)
        }
      end

      def show
        authorize!("system:user:list")

        render json: UserSerializer.render(@user)
      end

      def create
        authorize!("system:user:create")

        user = User.new(user_params)

        User.transaction do
          user.save!
          user.role_ids = permitted_role_ids if params.key?(:role_ids)
        end

        render json: UserSerializer.render(user.reload), status: :created
      end

      def update
        authorize!("system:user:update")

        User.transaction do
          @user.update!(user_params)
          @user.role_ids = permitted_role_ids if params.key?(:role_ids)
        end

        render json: UserSerializer.render(@user.reload)
      end

      def destroy
        authorize!("system:user:delete")

        raise ForbiddenError, "不能删除自己" if @user.id == current_user.id

        @user.destroy!
        render json: { message: "删除成功" }
      end

      # PATCH /api/v1/users/:id/status
      def status
        authorize!("system:user:update")

        raise ForbiddenError, "不能禁用自己" if @user.id == current_user.id

        @user.update!(status: params.require(:status))
        render json: UserSerializer.render(@user.reload)
      end

      # PATCH /api/v1/users/:id/password  管理员重置密码
      def reset_password
        authorize!("system:user:update")
        # 改自己的密码走个人中心（会校验当前密码），此接口供管理员帮他人重置
        raise ForbiddenError, "请到个人中心修改自己的密码" if @user.id == current_user.id

        @user.update!(password_params)
        render json: { message: "密码已重置" }
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def ensure_target_manageable!
        return if current_user.super_admin?
        return unless @user.super_admin?

        raise ForbiddenError, "超级管理员账号仅超级管理员可操作"
      end

      def user_params
        permitted = params.permit(:email, :name, :status)
        # 密码传了才带上，避免只改昵称时把密码覆盖为空
        permitted[:password] = params[:password] if params[:password].present?
        permitted[:password_confirmation] = params[:password_confirmation] if params[:password_confirmation].present?
        permitted
      end

      def password_params
        params.permit(:password, :password_confirmation)
      end

      # 只有超级管理员可以分配「超级管理员」角色
      def permitted_role_ids
        ids = Array(params[:role_ids]).map(&:to_i).uniq
        return ids if current_user.super_admin?
        return ids unless Role.where(id: ids, code: Role::SUPER_ADMIN_CODE).exists?

        raise ForbiddenError, "只有超级管理员可以分配「超级管理员」角色"
      end
    end
  end
end
