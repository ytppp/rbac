# 内容序列化器：把 Note 对象转成 app 首页卡片需要的字段。
# 前端字段名与数据库列名不同：cover_url→cover、author_name→author、likes_count→likes。
class NoteSerializer
  class << self
    def render(note, liked: false)
      {
        id: note.id,
        title: note.title,
        cover: note.cover_url,
        # cover_ratio 为宽/高比值，供前端设置 aspect-ratio，避免瀑布流抖动。
        cover_ratio: note.cover_ratio.to_f.round(4),
        author: note.author_name,
        # 作者头像：内容关联到真实用户且该用户上传过头像时才有值
        author_avatar: note.user&.avatar_url,
        avatar_color: note.avatar_color,
        likes: note.likes_count,
        channel: note.channel,
        liked: liked
      }
    end

    def render_collection(notes, liked_ids: [])
      notes.map { |note| render(note, liked: liked_ids.include?(note.id)) }
    end

    def render_admin(note)
      {
        id: note.id,
        title: note.title,
        cover_url: note.cover_url,
        cover_ratio: note.cover_ratio.to_f.round(4),
        author_name: note.author_name,
        avatar_color: note.avatar_color,
        likes_count: note.likes_count,
        channel: note.channel,
        sort: note.sort,
        created_at: note.created_at.iso8601,
        updated_at: note.updated_at.iso8601
      }
    end

    def render_admin_collection(notes)
      notes.map { |note| render_admin(note) }
    end
  end
end
