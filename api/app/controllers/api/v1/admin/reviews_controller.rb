# 审核模块：独立于内容管理，只有审核视角的用户能访问。
# 这里是审核员的工作台：看待审队列、通过、驳回。
module Api
  module V1
    module Admin
      class ReviewsController < Api::V1::BaseController
        before_action :set_note, only: %i[approve reject]

        def index
          authorize!("content:review:list")

          scope = Note.includes(:note_reviews, :tags)
          # 默认只看待审（含 auto_pending 打回来的），显式传 scope=all 看全部
          case params[:scope]
          when "all"
            # 不筛选，保留传进来的 status 过滤
          when "my"
            # 我处理过的：曾经有过 reviewer = current_user 的流水
            my_review_note_ids = NoteReview.where(reviewer: current_user).distinct.pluck(:note_id)
            scope = scope.where(id: my_review_note_ids)
          else
            scope = scope.where(status: "pending")
          end

          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.search(params[:keyword]) if params[:keyword].present?
          scope = scope.in_channel(params[:channel]) if params[:channel].present?

          paginated = paginate(scope.sorted)

          # 每条 note 带上最新一条流水的摘要，审核员一眼就能看到上一次状态变更
          items = paginated.map do |note|
            latest = note.note_reviews.timeline.last
            {
              id: note.id,
              title: note.title,
              cover_url: note.cover_url,
              author_name: note.author_name,
              user_id: note.user_id,
              channel: note.channel,
              status: note.status,
              created_at: note.created_at.iso8601,
              pending_since: latest&.created_at&.iso8601,
              last_action: latest&.action,
              last_reason: latest&.reason
            }
          end

          render json: {
            items: items,
            channels: Note.channel_list_all,
            meta: pagination_meta(paginated)
          }
        end

        # POST /admin/reviews/:id/approve —— 审核通过
        def approve
          authorize!("content:review:approve")

          raise ForbiddenError, "只有待审状态才能通过" unless @note.pending?

          previous = @note.status
          @note.update!(status: "published")
          write_review(@note, previous, "published", action: "approve")

          NotificationJob.perform_later(user_id: @note.user_id, action: "review", note_id: @note.id)
          render json: NoteSerializer.render_admin(@note.reload)
        end

        # POST /admin/reviews/:id/reject —— 审核驳回，必须带 reason
        def reject
          authorize!("content:review:reject")

          raise ForbiddenError, "只有待审状态才能驳回" unless @note.pending?
          reason = params[:reason].to_s.strip
          raise ActionController::ParameterMissing, :reason if reason.blank?

          previous = @note.status
          @note.update!(status: "rejected")
          write_review(@note, previous, "rejected", action: "reject", reason: reason)

          NotificationJob.perform_later(user_id: @note.user_id, action: "review", note_id: @note.id)
          render json: NoteSerializer.render_admin(@note.reload)
        end

        private

        def set_note
          @note = Note.find(params[:id])
        end

        def write_review(note, from_status, to_status, action:, reason: nil)
          NoteReview.create!(
            note: note,
            from_status: Note::STATUSES[from_status.to_sym],
            to_status: Note::STATUSES[to_status.to_sym],
            action: action,
            reviewer: current_user,
            reason: reason
          )
        end
      end
    end
  end
end
