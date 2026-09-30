module Api
  module V1
    # 面向 app 模块的内容接口。
    # 内容社区是公开访问的，所以这里跳过登录校验，只开放只读查询。
    class NotesController < BaseController
      # skip_before_action 用来「撤销」父类里的 before_action。
      # BaseController 默认要求每个接口都登录，内容接口不需要，就在这里单独豁免。
      skip_before_action :authenticate_user!, only: %i[index]

      # GET /api/v1/notes
      # 支持 channel（「推荐」或留空表示不过滤）、keyword、page、per_page
      def index
        # 这一行链式调用了三个 scope，可以按顺序读：
        #   Note.in_channel(...)  先按频道筛（传「推荐」或空则不过滤）
        #        .search(...)     再按关键词模糊搜索（标题/作者/频道）
        #        .sorted          最后排序
        # 得到的仍然只是「查询条件」，直到 paginate 里才真正去查数据库。
        paginated = paginate(Note.in_channel(params[:channel]).search(params[:keyword]).sorted)

        render json: {
          items: NoteSerializer.render_collection(paginated),
          # 顺带把频道列表返回，前端顶部的频道按钮就直接用它渲染，不用再写死一遍
          channels: Note.channel_list,
          meta: pagination_meta(paginated)
        }
      end
    end
  end
end
