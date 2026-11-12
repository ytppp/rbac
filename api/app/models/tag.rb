# 内容标签：用户发布时可直接创建，管理员在后台统一维护
class Tag < ApplicationRecord
  has_many :note_tags, dependent: :destroy
  has_many :notes, through: :note_tags

  validates :name, presence: true, length: { maximum: 20 }, uniqueness: true
  validates :notes_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  normalizes :name, with: ->(value) { value.to_s.strip }

  # 后台：手动排序优先，其次按使用量
  scope :sorted, -> { order(sort: :asc, notes_count: :desc, id: :asc) }
end
