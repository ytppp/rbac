# 用户举报：可以举报内容或评论，同一用户对同一对象只能举报一次
class Report < ApplicationRecord
  belongs_to :note, optional: true
  belongs_to :user
  belongs_to :comment, optional: true
  belongs_to :handler, class_name: "User", foreign_key: :handled_by, optional: true

  REASONS = %w[spam ads abuse copyright other].freeze

  enum :status, { pending: 0, resolved: 1, ignored: 2 }, validate: true

  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :detail, length: { maximum: 500 }
  # 举报评论时只按评论去重，避免「举报过内容」挡住对评论的举报
  validates :note_id, uniqueness: { scope: :user_id, message: "已经举报过该内容" },
                      if: -> { note_id.present? && comment_id.blank? }
  validates :comment_id, uniqueness: { scope: :user_id, message: "已经举报过该评论" }, if: -> { comment_id.present? }
  validate :target_must_exist

  scope :recent, -> { order(created_at: :desc) }

  private

  def target_must_exist
    errors.add(:base, "举报对象不能为空") if note_id.blank? && comment_id.blank?
  end
end
