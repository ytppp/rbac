module Api
  module V1
    # 内容标签：app 端公开读取（热门标签云、标签筛选）
    class TagsController < BaseController
      skip_before_action :authenticate_user!, only: %i[index]

      # GET /api/v1/tags
      def index
        tags = Tag.sorted.limit(30)

        render json: {
          items: tags.map { |tag| { id: tag.id, name: tag.name, notes_count: tag.notes_count } }
        }
      end
    end
  end
end
