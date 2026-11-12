# 站内通知：评论 / 点赞 / 审核结果
class Notification < ApplicationRecord
  ACTIONS = %w[comment like review].freeze

  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :note, optional: true

  validates :action, inclusion: { in: ACTIONS }

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # 统一入口：不给自己发通知
  def self.push(user_id:, actor_id: nil, action:, note_id: nil, comment_id: nil)
    return if user_id.blank? || user_id == actor_id

    create!(user_id: user_id, actor_id: actor_id, action: action, note_id: note_id, comment_id: comment_id)
  end
end
