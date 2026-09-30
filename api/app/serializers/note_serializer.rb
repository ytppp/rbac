# 内容序列化器：把 Note 对象转成 app 首页卡片需要的字段。
#
# 注意这里的字段名故意和数据库列名不完全一样：
#   数据库 cover_url     -> 前端 cover
#   数据库 author_name   -> 前端 author
#   数据库 likes_count   -> 前端 likes
# 这样前端拿到的名字更短更好用，改名也不会牵连到数据库。
class NoteSerializer
  class << self
    def render(note)
      {
        id: note.id,
        title: note.title,
        cover: note.cover_url,
        # cover_ratio 是宽/高比值，前端用它给图片容器设 aspect-ratio，
        # 这样图片还没下载完时高度就是确定的，瀑布流不会「抖动」。
        # to_f 保证它是浮点数（数据库 decimal 类型取出来可能是 BigDecimal），
        # round(4) 保留 4 位小数，避免输出一长串无意义的精度。
        cover_ratio: note.cover_ratio.to_f.round(4),
        author: note.author_name,
        avatar_color: note.avatar_color,
        likes: note.likes_count,
        channel: note.channel
      }
    end

    def render_collection(notes)
      notes.map { |note| render(note) }
    end
  end
end
