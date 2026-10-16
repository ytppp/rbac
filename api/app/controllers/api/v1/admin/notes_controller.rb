# 管理后台的内容管理接口（增删改查），放在 admin 命名空间下以区别于前台公开接口。
module Api
  module V1
    module Admin
      class NotesController < Api::V1::BaseController
        before_action :set_note, only: %i[update destroy]

        def index
          authorize!("content:note:list")

          scope = Note.search(params[:keyword]).in_channel(params[:channel])
          paginated = paginate(scope.sorted)

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
          note.save!
          render json: NoteSerializer.render_admin(note), status: :created
        end

        def update
          authorize!("content:note:update")

          @note.update!(note_params)
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

        # 白名单不含 likes_count（后台不能手改点赞数），
        # 也不含 author_name：作者由当前登录用户决定，不通过参数传入
        def note_params
          params.permit(:title, :cover_url, :cover_ratio, :avatar_color, :channel, :sort)
        end
      end
    end
  end
end
