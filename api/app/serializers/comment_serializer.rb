# 评论序列化：顶层评论带一层回复（楼中楼），回复不再继续嵌套。
class CommentSerializer
  class << self
    def render(comment, liked: false, current_user_id: nil, replies: [], liked_ids: Set.new)
      {
        id: comment.id,
        content: comment.content,
        created_at: comment.created_at.iso8601,
        likes: comment.likes_count,
        liked: liked,
        # 前端用来判断是否显示「删除」入口
        mine: current_user_id.present? && comment.user_id == current_user_id,
        author: {
          id: comment.user_id,
          name: comment.user&.name,
          avatar_url: comment.user&.avatar_url
        },
        replies: replies.map do |reply|
          render(
            reply,
            liked: liked_ids.include?(reply.id),
            current_user_id: current_user_id,
            replies: [],
            liked_ids: liked_ids
          )
        end
      }
    end
  end
end
