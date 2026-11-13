# 内容收藏：同一用户对同一条内容只能收藏一次
class NoteFavorite < ApplicationRecord
  belongs_to :user
  belongs_to :note
end
