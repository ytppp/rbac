module Api
  module V1
    # 面向 app 模块的内容接口。
    class NotesController < BaseController
      # 列表公开访问，跳过登录校验；like / unlike 仍需登录
      skip_before_action :authenticate_user!, only: %i[index]

      # 列表带 token 时顺便识别用户，用于标记已赞内容
      before_action :optional_authenticate_user!, only: %i[index]

      before_action :set_note, only: %i[like unlike]

      def index
        # includes(:user) 预加载作者，避免序列化 author_avatar 时逐条查库
        paginated = paginate(Note.in_channel(params[:channel]).search(params[:keyword]).sorted.includes(:user))

        # 一次性查出本页已赞 id，避免序列化时逐条查询
        liked_ids = if current_user
          NoteLike.where(user_id: current_user.id, note_id: paginated.map(&:id)).pluck(:note_id).to_set
        else
          Set.new
        end

        render json: {
          items: NoteSerializer.render_collection(paginated, liked_ids: liked_ids),
          channels: Note.channel_list,
          meta: pagination_meta(paginated)
        }
      end

      # POST /api/v1/notes/:id/like
      def like
        # create_or_find_by 保证重复点赞不报错且不产生重复记录
        current_user.note_likes.create_or_find_by(note: @note)

        render json: { liked: true, likes: @note.reload.likes_count }
      end

      # DELETE /api/v1/notes/:id/unlike
      def unlike
        current_user.note_likes.where(note: @note).destroy_all

        render json: { liked: false, likes: @note.reload.likes_count }
      end

      private

      def set_note
        @note = Note.find(params[:id])
      end
    end
  end
end
