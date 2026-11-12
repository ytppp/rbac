module Api
  module V1
    module Admin
      # 标签维护：用户发布内容时可以创建标签，管理员在这里统一改名 / 排序 / 删除
      class TagsController < Api::V1::BaseController
        before_action :set_tag, only: %i[update destroy]

        def index
          authorize!("content:tag:list")

          scope = Tag.sorted
          if params[:keyword].present?
            pattern = "%#{Tag.sanitize_sql_like(params[:keyword].to_s.strip)}%"
            scope = scope.where("tags.name ILIKE ?", pattern)
          end

          paginated = paginate(scope)
          render json: {
            items: paginated.map { |tag| tag_json(tag) },
            meta: pagination_meta(paginated)
          }
        end

        def create
          authorize!("content:tag:create")

          tag = Tag.create!(name: params[:name], sort: params[:sort].to_i)
          render json: tag_json(tag), status: :created
        end

        def update
          authorize!("content:tag:update")

          @tag.update!(
            name: params[:name].presence || @tag.name,
            sort: params[:sort].nil? ? @tag.sort : params[:sort].to_i
          )
          render json: tag_json(@tag)
        end

        def destroy
          authorize!("content:tag:delete")

          @tag.destroy!
          render json: { message: "删除成功" }
        end

        private

        def set_tag
          @tag = Tag.find(params[:id])
        end

        def tag_json(tag)
          {
            id: tag.id,
            name: tag.name,
            notes_count: tag.notes_count,
            sort: tag.sort,
            created_at: tag.created_at.iso8601
          }
        end
      end
    end
  end
end
