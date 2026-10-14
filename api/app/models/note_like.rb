# 点赞记录模型，对应 note_likes 表。
class NoteLike < ApplicationRecord
  # counter_cache 自动维护 note.likes_count 的增减
  belongs_to :note, counter_cache: :likes_count
  belongs_to :user
end
