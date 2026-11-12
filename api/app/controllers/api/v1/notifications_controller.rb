module Api
  module V1
    # 站内通知列表与已读
    class NotificationsController < BaseController
      # GET /api/v1/notifications
      def index
        paginated = paginate(current_user.notifications.includes(:actor, :note).recent)

        render json: {
          items: paginated.map { |item| notification_json(item) },
          unread: current_user.notifications.unread.count,
          meta: pagination_meta(paginated)
        }
      end

      # PATCH /api/v1/notifications/:id/read
      def read
        current_user.notifications.find(params[:id]).update!(read_at: Time.current)
        render json: { unread: current_user.notifications.unread.count }
      end

      # PATCH /api/v1/notifications/read_all
      def read_all
        current_user.notifications.unread.update_all(read_at: Time.current)
        render json: { unread: 0 }
      end

      private

      def notification_json(item)
        {
          id: item.id,
          action: item.action,
          read: item.read_at.present?,
          created_at: item.created_at.iso8601,
          actor: item.actor && {
            id: item.actor.id,
            name: item.actor.name,
            avatar_url: item.actor.avatar_url
          },
          note: item.note && {
            id: item.note.id,
            title: item.note.title
          }
        }
      end
    end
  end
end
