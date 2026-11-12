# 管理后台的内容管理接口（增删改查），放在 admin 命名空间下以区别于前台公开接口。
module Api
  module V1
    module Admin
      class NotesController < Api::V1::BaseController
        before_action :set_note, only: %i[update destroy]

        def index
          authorize!("content:note:list")

          scope = Note.search(params[:keyword]).in_channel(params[:channel])
          scope = scope.where(status: params[:status]) if params[:status].present?
          paginated = paginate(scope.sorted.includes(:tags))

          render json: {
            items: NoteSerializer.render_admin_collection(paginated),
            channels: Note.channel_list,
            meta: pagination_meta(paginated)
          }
        end

        def create
          authorize!("content:note:create")

          note = Note.new(note_params)
          # 作者固定为当前登录用户（即持有 content:note:create 权限的这个人）
          note.user = current_user
          note.author_name = current_user.name
          # 只有具备审核权限的人才能直接指定状态；其他人新建的内容一律进入待审
          note.status = if can_review?
            params[:status].presence || "published"
          else
            "pending"
          end
          note.save!
          sync_tags(note, params[:tags])
          render json: NoteSerializer.render_admin(note.reload), status: :created
        end

        def update
          authorize!("content:note:update")

          previous_status = @note.status
          # 状态流转（通过 / 下架）属于审核动作，需要单独的审核权限
          if params[:status].present? && params[:status] != previous_status
            authorize!("content:note:review")
          end

          @note.update!(note_params)
          sync_tags(@note, params[:tags])
          if params[:status].present?
            @note.update!(status: params[:status])
            notify_review(@note, previous_status) if @note.status != previous_status
          end
          render json: NoteSerializer.render_admin(@note.reload)
        end

        def destroy
          authorize!("content:note:delete")

          @note.destroy!
          render json: { message: "删除成功" }
        end

        private

        def set_note
          @note = Note.find(params[:id])
        end

        # 标签按名字提交：已有标签直接复用，新名字自动创建；最多 10 个并去重
        def sync_tags(note, names)
          return if names.nil?

          cleaned = Array(names).map { |name| name.to_s.strip }.reject(&:empty?).uniq.first(10)
          note.tags = cleaned.map { |name| Tag.find_or_create_by!(name: name) }
        end

        # 审核结果（通过 / 下架）通知作者
        def notify_review(note, previous_status)
          return unless %w[published archived].include?(note.status)
          return if previous_status == note.status

          Notification.push(user_id: note.user_id, action: "review", note_id: note.id)
        end

        # 是否具备内容审核权限（超级管理员默认具备）
        def can_review?
          current_user.super_admin? || current_user.permission_codes.include?("content:note:review")
        end

        # 白名单不含 likes_count（后台不能手改点赞数），
        # 也不含 author_name：作者由当前登录用户决定，不通过参数传入
        # sections 为分段行程数组，每段可带交通方式、起终点、耗时、完成状态与图片
        def note_params
          params.permit(
            :title, :cover_url, :cover_ratio, :avatar_color, :channel, :sort, :content,
            sections: [
              :type, :duration, :completed, :title, :content,
              { images: [] },
              { origin: %i[lng lat name] },
              { destination: %i[lng lat name] }
            ]
          )
        end
      end
    end
  end
end
