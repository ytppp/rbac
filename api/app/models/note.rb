# 内容模型，对应数据库里的 notes 表 —— 也就是 app 模块首页那些「瀑布流卡片」。
#
# 它和 RBAC 那几张表没有任何关联，纯粹是给内容社区用的数据源。
class Note < ApplicationRecord
  # 虚拟频道：前端默认选中，代表不做频道过滤。
  # 它并不是数据库里真实存在的 channel 值，只是一个约定用的字符串。
  ALL_CHANNEL = "推荐".freeze

  validates :title, presence: true, length: { maximum: 100 }
  validates :cover_url, presence: true
  validates :author_name, presence: true, length: { maximum: 50 }
  validates :channel, presence: true, length: { maximum: 30 }
  validates :avatar_color,
            presence: true,
            # #RRGGBB 格式的颜色值
            format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "必须是 #RRGGBB 格式" }
  validates :likes_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cover_ratio, numericality: { greater_than: 0 }

  # 先按 sort 升序，sort 相同的按 id 升序（保证顺序稳定）
  scope :sorted, -> { order(sort: :asc, id: :asc) }

  # 「推荐」是虚拟频道，等价于不过滤
  scope :in_channel, ->(channel) {
    next all if channel.blank? || channel == ALL_CHANNEL

    where(channel: channel)
  }

  scope :search, ->(keyword) {
    next all if keyword.blank?

    pattern = "%#{sanitize_sql_like(keyword.to_s.strip)}%"
    # 标题、作者、频道任意一处包含关键词就算命中
    where(
      "notes.title ILIKE :pattern OR notes.author_name ILIKE :pattern OR notes.channel ILIKE :pattern",
      pattern: pattern
    )
  }

  # 频道列表：虚拟频道「推荐」排最前，其余按内容里首次出现的顺序。
  # pluck(:channel) 只取 channel 这一列返回数组，uniq 去重。
  # 不用 DISTINCT，Postgres 会要求 ORDER BY 的列出现在 SELECT 列表里。
  def self.channel_list
    [ALL_CHANNEL] + sorted.pluck(:channel).uniq
  end
end
