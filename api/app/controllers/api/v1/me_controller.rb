module Api
  module V1
    # 个人中心：我发布的内容、我的收藏、我点赞的内容
    class MeController < BaseController
      # GET /api/v1/me/notes
      def notes
        render_notes(current_user.notes.published.sorted)
      end

      # GET /api/v1/me/favorites
      def favorites
        scope = Note
          .joins(:note_favorites)
          .where(note_favorites: { user_id: current_user.id })
          .order("note_favorites.created_at DESC")
        render_notes(scope, all_favorited: true)
      end

      # GET /api/v1/me/likes
      def likes
        scope = Note
          .joins(:note_likes)
          .where(note_likes: { user_id: current_user.id })
          .order("note_likes.created_at DESC")
        render_notes(scope)
      end

      private

      def render_notes(scope, all_favorited: false)
        paginated = paginate(scope.includes(:user))
        note_ids = paginated.map(&:id)

        liked_ids = NoteLike.where(user_id: current_user.id, note_id: note_ids).pluck(:note_id).to_set
        favorited_ids = if all_favorited
          note_ids.to_set
        else
          NoteFavorite.where(user_id: current_user.id, note_id: note_ids).pluck(:note_id).to_set
        end

        render json: {
          items: NoteSerializer.render_collection(paginated, liked_ids: liked_ids, favorited_ids: favorited_ids),
          meta: pagination_meta(paginated)
        }
      end
    end
  end
end
