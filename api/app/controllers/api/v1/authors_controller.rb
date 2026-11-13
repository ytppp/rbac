module Api
  module V1
    # 作者主页：公开查看作者信息与其发布的内容
    class AuthorsController < BaseController
      skip_before_action :authenticate_user!, only: %i[show]
      before_action :optional_authenticate_user!, only: %i[show]

      # GET /api/v1/authors/:id
      def show
        author = User.find(params[:id])
        paginated = paginate(author.notes.published.sorted.includes(:user, :tags))
        note_ids = paginated.map(&:id)

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
          author: {
            id: author.id,
            name: author.name,
            avatar_url: author.avatar_url,
            notes_count: author.notes.count
          },
          items: NoteSerializer.render_collection(paginated, liked_ids: liked_ids, favorited_ids: favorited_ids),
          meta: pagination_meta(paginated)
        }
      end
    end
  end
end
