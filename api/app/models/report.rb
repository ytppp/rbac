# 用户举报：同一用户对同一条内容只能举报一次，处理后保留记录
class Report < ApplicationRecord
  belongs_to :note
  belongs_to :user
  belongs_to :handler, class_name: "User", foreign_key: :handled_by, optional: true

  REASONS = %w[spam ads abuse copyright other].freeze

  enum :status, { pending: 0, resolved: 1, ignored: 2 }, validate: true

  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :detail, length: { maximum: 500 }
  validates :user_id, uniqueness: { scope: :note_id, message: "已经举报过该内容" }

  scope :recent, -> { order(created_at: :desc) }
end
