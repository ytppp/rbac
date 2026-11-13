module Api
  module V1
    module Admin
      # 管理后台首页数据看板
      class DashboardController < Api::V1::BaseController
        def stats
          authorize!("dashboard")

          since = 13.days.ago.beginning_of_day
          note_trend = Note.where(created_at: since..).group("date_trunc('day', created_at)").count
          like_trend = NoteLike.where(created_at: since..).group("date_trunc('day', created_at)").count

          render json: {
            notes: {
              total: Note.count,
              published: Note.published.count,
              pending: Note.pending.count,
              draft: Note.draft.count,
              archived: Note.archived.count
            },
            users: {
              total: User.count,
              new_this_week: User.where(created_at: 7.days.ago..).count
            },
            likes: NoteLike.count,
            comments: Comment.count,
            favorites: NoteFavorite.count,
            pending_reports: Report.pending.count,
            trend: build_trend(since, note_trend, like_trend)
          }
        end

        private

        # 近 14 天按天聚合：内容新增 / 点赞新增
        def build_trend(since, note_trend, like_trend)
          (0..13).map do |offset|
            day = (since + offset.days).to_date
            {
              date: day.iso8601,
              notes: note_trend.select { |key, _| key.to_date == day }.values.sum,
              likes: like_trend.select { |key, _| key.to_date == day }.values.sum
            }
          end
        end
      end
    end
  end
end
