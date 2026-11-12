module Api
  module V1
    # 面向 app 模块的内容接口。
    class NotesController < BaseController
      # 列表与详情公开访问，跳过登录校验；like / unlike 仍需登录
      skip_before_action :authenticate_user!, only: %i[index show]

      # 带 token 时顺便识别用户，用于标记已赞内容
      before_action :optional_authenticate_user!, only: %i[index show]

      before_action :set_note, only: %i[show like unlike favorite unfavorite]

      def index
        # includes 预加载作者与标签，避免序列化时逐条查库
        scope = Note
          .published
          .in_channel(params[:channel])
          .with_tag(params[:tag])
          .search(params[:keyword])
          .sorted
          .includes(:user, :tags)
        paginated = paginate(scope)
        note_ids = paginated.map(&:id)

        # 一次性查出本页已赞 / 已收藏 id，避免序列化时逐条查询
        liked_ids = if current_user
          NoteLike.where(user_id: current_user.id, note_id: note_ids).pluck(:note_id).to_set
        else
          Set.new
        end
        favorited_ids = if current_user
          NoteFavorite.where(user_id: current_user.id, note_id: note_ids).pluck(:note_id).to_set
        else
          Set.new
        end

        render json: {
          items: NoteSerializer.render_collection(paginated, liked_ids: liked_ids, favorited_ids: favorited_ids),
          channels: Note.channel_list,
          meta: pagination_meta(paginated)
        }
      end

      # GET /api/v1/notes/:id
      # 详情页：正文 Markdown + 分段行程（每段含图片）
      def show
        liked = current_user ? NoteLike.exists?(user_id: current_user.id, note_id: @note.id) : false
        favorited = current_user ? NoteFavorite.exists?(user_id: current_user.id, note_id: @note.id) : false
        render json: NoteSerializer.render_detail(@note, liked: liked, favorited: favorited)
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

      # POST /api/v1/notes/:id/favorite
      def favorite
        current_user.note_favorites.create_or_find_by(note: @note)

        render json: { favorited: true }
      end

      # DELETE /api/v1/notes/:id/unfavorite
      def unfavorite
        current_user.note_favorites.where(note: @note).destroy_all

        render json: { favorited: false }
      end

      private

      def set_note
        # app 端只能访问已发布内容
        @note = Note.published.find(params[:id])
      end
    end
  end
end
