module Api
  module V1
    # 举报：登录用户可以举报已发布内容，或内容下的评论
    class ReportsController < BaseController
      # POST /api/v1/notes/:id/reports
      def create
        note = Note.published.find(params[:id])

        save_report!(note: note)
      end

      # POST /api/v1/comments/:id/reports
      def create_comment
        comment = Comment.joins(:note).merge(Note.published).find(params[:id])

        save_report!(note: comment.note, comment: comment)
      end

      private

      def save_report!(note: nil, comment: nil)
        report = Report.new(
          user: current_user,
          note: note,
          comment: comment,
          reason: params[:reason],
          detail: params[:detail].presence
        )
        report.save!

        render json: { ok: true }, status: :created
      end
    end
  end
end
