module Api
  module V1
    module Admin
      # 举报处理：查看待处理举报，标记已处理 / 已忽略，可直接下架内容
      class ReportsController < Api::V1::BaseController
        def index
          authorize!("content:report:list")

          scope = Report.includes(:user, note: :user).recent
          scope = scope.where(status: params[:status]) if params[:status].present?
          paginated = paginate(scope)

          render json: {
            items: paginated.map { |report| report_json(report) },
            meta: pagination_meta(paginated)
          }
        end

        def update
          authorize!("content:report:handle")

          report = Report.find(params[:id])
          report.update!(
            status: params[:status].presence || "resolved",
            handled_by: current_user.id,
            handled_at: Time.current
          )

          # 处理时可以直接把内容下架，并通知作者
          if params[:archive_note].to_s == "true"
            report.note.update!(status: :archived)
            Notification.push(user_id: report.note.user_id, action: "review", note_id: report.note.id)
          end

          render json: report_json(report.reload)
        end

        private

        def report_json(report)
          {
            id: report.id,
            reason: report.reason,
            detail: report.detail,
            status: report.status,
            created_at: report.created_at.iso8601,
            handled_at: report.handled_at&.iso8601,
            reporter: { id: report.user_id, name: report.user.name },
            note: {
              id: report.note_id,
              title: report.note.title,
              status: report.note.status
            }
          }
        end
      end
    end
  end
end
