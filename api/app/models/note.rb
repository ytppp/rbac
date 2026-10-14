# 内容模型，对应 notes 表（首页瀑布流卡片）。
class Note < ApplicationRecord
  # 虚拟频道「推荐」，并非真实 channel 值，仅作约定
  ALL_CHANNEL = "推荐".freeze

  validates :title, presence: true, length: { maximum: 100 }
  validates :cover_url, presence: true
  validates :author_name, presence: true, length: { maximum: 50 }
  validates :channel, presence: true, length: { maximum: 30 }
  validates :avatar_color,
            presence: true,
            format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "必须是 #RRGGBB 格式" }
  validates :likes_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cover_ratio, numericality: { greater_than: 0 }

  # likes_count 由 NoteLike 的 counter_cache 自动维护，无需手动处理
  has_many :note_likes, dependent: :destroy

  scope :sorted, -> { order(sort: :asc, id: :asc) }

  scope :in_channel, ->(channel) {
    next all if channel.blank? || channel == ALL_CHANNEL

    where(channel: channel)
  }

  scope :search, ->(keyword) {
    next all if keyword.blank?

    pattern = "%#{sanitize_sql_like(keyword.to_s.strip)}%"
    where(
      "notes.title ILIKE :pattern OR notes.author_name ILIKE :pattern OR notes.channel ILIKE :pattern",
      pattern: pattern
    )
  }

  # 不用 DISTINCT：Postgres 要求 ORDER BY 的列出现在 SELECT 列表中
  def self.channel_list
    [ALL_CHANNEL] + sorted.pluck(:channel).uniq
  end
end
