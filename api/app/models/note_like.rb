# 点赞记录模型，对应 note_likes 表。
class NoteLike < ApplicationRecord
  # counter_cache 自动维护 note.likes_count 的增减
  belongs_to :note, counter_cache: :likes_count
  belongs_to :user

  # 被点赞时给作者发一条站内通知
  after_create_commit :notify_note_author

  private

  def notify_note_author
    NotificationJob.perform_later(
      user_id: note&.user_id, actor_id: user_id, action: "like", note_id: note_id
    )
  end
end
