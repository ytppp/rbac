# 评论点赞：同一用户对同一条评论只能点赞一次
class CommentLike < ApplicationRecord
  belongs_to :user
  belongs_to :comment, counter_cache: :likes_count
end
