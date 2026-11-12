# 内容与标签的多对多关联，notes_count 由 counter_cache 维护
class NoteTag < ApplicationRecord
  belongs_to :note
  belongs_to :tag, counter_cache: :notes_count
end
