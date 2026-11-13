# 内容评论：顶层评论 parent 为空，回复指向同一条内容下的顶层评论。
class Comment < ApplicationRecord
  belongs_to :note
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true

  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy
  has_many :comment_likes, dependent: :destroy
  has_many :reports, dependent: :destroy

  validates :content, presence: true, length: { maximum: 500 }

  # 顶层评论按时间正序，回复按时间正序
  scope :roots, -> { where(parent_id: nil) }
  scope :oldest_first, -> { order(created_at: :asc, id: :asc) }

  # 回复只能挂在同一条内容的顶层评论下
  validate :parent_must_be_root_of_same_note, if: -> { parent_id.present? }

  # 被评论时给内容作者发一条站内通知
  after_create_commit :notify_note_author

  private

  def notify_note_author
    NotificationJob.perform_later(
      user_id: note&.user_id, actor_id: user_id, action: "comment",
      note_id: note_id, comment_id: id
    )
  end

  def parent_must_be_root_of_same_note
    return if parent.nil?

    errors.add(:parent_id, "必须是同一条内容下的顶层评论") if parent.parent_id.present? || parent.note_id != note_id
  end
end
