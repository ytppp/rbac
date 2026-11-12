# 站内通知异步 job：评论 / 点赞 / 审核触发后丢进队列。
# queue_adapter 由 application.rb 决定：有 REDIS_URL 用 Sidekiq，没就走 :async（进程内）。
class NotificationJob < ApplicationJob
  queue_as :default

  def perform(attrs)
    return if attrs.nil? || attrs["user_id"].blank?

    Notification.push(
      user_id:      attrs["user_id"],
      actor_id:     attrs["actor_id"],
      action:       attrs["action"],
      note_id:      attrs["note_id"],
      comment_id:   attrs["comment_id"],
    )
  end
end
