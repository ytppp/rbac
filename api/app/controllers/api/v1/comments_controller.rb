module Api
  module V1
    # 内容评论：列表公开，发布 / 删除 / 点赞需要登录。
    class CommentsController < BaseController
      skip_before_action :authenticate_user!, only: %i[index]
      before_action :optional_authenticate_user!, only: %i[index]

      # GET /api/v1/notes/:note_id/comments
      # 返回顶层评论（分页）+ 每条的楼中楼回复
      def index
        note = Note.published.find(params[:note_id])
        # 默认按热度（B 站默认），也支持按时间倒序
        roots_scope = note.comments.roots.includes(:user)
        roots_scope = if params[:sort] == "time"
          roots_scope.order(created_at: :desc, id: :desc)
        else
          roots_scope.order(likes_count: :desc, created_at: :desc)
        end

        roots = paginate(roots_scope)
        root_ids = roots.map(&:id)
        replies = root_ids.any? ? Comment.where(parent_id: root_ids).oldest_first.includes(:user).to_a : []

        liked_ids = if current_user
          CommentLike.where(user_id: current_user.id, comment_id: root_ids + replies.map(&:id)).pluck(:comment_id).to_set
        else
          Set.new
        end
        replies_by_parent = replies.group_by(&:parent_id)

        render json: {
          items: roots.map do |comment|
            CommentSerializer.render(
              comment,
              liked: liked_ids.include?(comment.id),
              current_user_id: current_user&.id,
              replies: replies_by_parent[comment.id] || [],
              liked_ids: liked_ids
            )
          end,
          meta: pagination_meta(roots),
          total: note.comments.count
        }
      end

      # POST /api/v1/notes/:note_id/comments
      def create
        # 防刷评论：同一 IP 每分钟最多 20 条
        throttle!(key: "comments/create", limit: 20, period: 1.minute)

        note = Note.published.find(params[:note_id])
        payload = params.permit(:content, :parent_id)
        comment = note.comments.new(
          user: current_user,
          content: payload[:content].to_s.strip,
          parent_id: payload[:parent_id].presence
        )
        comment.save!

        render json: CommentSerializer.render(comment.reload, current_user_id: current_user.id), status: :created
      end

      # DELETE /api/v1/comments/:id
      def destroy
        comment = Comment.find(params[:id])
        raise ForbiddenError, "只能删除自己的评论" unless comment.user_id == current_user.id || current_user.super_admin?

        comment.destroy
        render json: { ok: true }
      end

      # POST /api/v1/comments/:id/like
      def like
        comment = Comment.find(params[:id])
        current_user.comment_likes.create_or_find_by(comment: comment)

        render json: { liked: true, likes: comment.reload.likes_count }
      end

      # DELETE /api/v1/comments/:id/unlike
      def unlike
        comment = Comment.find(params[:id])
        current_user.comment_likes.where(comment: comment).destroy_all

        render json: { liked: false, likes: comment.reload.likes_count }
      end
    end
  end
end
