module Api
  module V1
    # 内容举报：登录用户可以举报已发布内容，同一内容只能举报一次
    class ReportsController < BaseController
      def create
        note = Note.published.find(params[:id])
        report = note.reports.new(
          user: current_user,
          reason: params[:reason],
          detail: params[:detail].presence
        )
        report.save!

        render json: { ok: true }, status: :created
      end
    end
  end
end
