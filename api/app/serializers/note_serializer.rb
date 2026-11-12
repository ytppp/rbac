# 内容序列化器：把 Note 对象转成 app 首页卡片需要的字段。
# 前端字段名与数据库列名不同：cover_url→cover、author_name→author、likes_count→likes。
class NoteSerializer
  class << self
    def render(note, liked: false, favorited: false)
      {
        id: note.id,
        title: note.title,
        cover: note.cover_url,
        # cover_ratio 为宽/高比值，供前端设置 aspect-ratio，避免瀑布流抖动。
        cover_ratio: note.cover_ratio.to_f.round(4),
        author: note.author_name,
        # 作者关联：有真实用户时前端才能点进作者主页
        author_id: note.user_id,
        # 作者头像：内容关联到真实用户且该用户上传过头像时才有值
        author_avatar: note.user&.avatar_url,
        avatar_color: note.avatar_color,
        likes: note.likes_count,
        channel: note.channel,
        # 标签名列表，前端展示为可点击的 chips
        tags: note.tags.map(&:name),
        liked: liked,
        favorited: favorited
      }
    end

    def render_collection(notes, liked_ids: [], favorited_ids: [])
      notes.map do |note|
        render(note, liked: liked_ids.include?(note.id), favorited: favorited_ids.include?(note.id))
      end
    end

    # 详情页：在列表字段基础上追加 Markdown 正文与分段行程（含每段图片）
    def render_detail(note, liked: false, favorited: false)
      render(note, liked: liked, favorited: favorited).merge(
        content: note.content.to_s,
        sections: note.sections || []
      )
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
        status: note.status,
        # 后台编辑时回显标签
        tags: note.tags.map(&:name),
        content: note.content.to_s,
        sections: note.sections || [],
        created_at: note.created_at.iso8601,
        updated_at: note.updated_at.iso8601
      }
    end

    def render_admin_collection(notes)
      notes.map { |note| render_admin(note) }
    end
  end
end
