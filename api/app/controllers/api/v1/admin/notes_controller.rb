# 管理后台的内容管理接口（增删改查 + 提交/撤回 + 审核历史）。
# 核心规则：
#   - 默认所有内容作者只能看到、只能编辑自己的；
#   - 拥有 content:review:list 权限（审核模块入口）或超管才能看全部并绕过状态机；
#   - 内容永远不会「凭空」变成 published，必须经过审核；
#   - published/archived 态的内容一旦被改了「内容字段」（title/cover/content/sections/avatar_color），
#     后端会自动把状态打回 pending 并记录 auto_pending 流水，任何人都逃不过；
#   - 所有状态变更都写 note_reviews，前端按权限决定是否脱敏审核人姓名。
module Api
  module V1
    module Admin
      class NotesController < Api::V1::BaseController
        before_action :set_note, only: %i[update destroy submit withdraw reviews]

        # 这几个字段被视为「内容本身」的变更：published 后修改任何一个都会触发重新审核。
        # sort / channel / tags 属于运营字段，由超管/审核维护，不走内容审核链路。
        CONTENT_FIELDS = %w[title cover_url cover_ratio avatar_color content sections].freeze

        def index
          authorize!("content:note:list")

          scope = Note.search(params[:keyword]).in_channel(params[:channel])
          scope = scope.where(status: params[:status]) if params[:status].present?
          # 默认只看自己的；审核权限/超管才能看全部
          scope = scope.where(user_id: current_user.id) unless has_review_privilege?
          paginated = paginate(scope.sorted.includes(:tags))

          render json: {
            items: NoteSerializer.render_admin_collection(paginated),
            channels: Note.channel_list_all,
            meta: pagination_meta(paginated)
          }
        end

        def create
          authorize!("content:note:create")

          note = Note.new(note_params)
          note.user = current_user
          note.author_name = current_user.name
          # 新建一律从草稿起，避免任何绕过审核直接上线的口子
          note.status = "draft"
          note.save!
          sync_tags(note, params[:tags])
          # 审核时间线等作者真正点「提交审核」时再写；create 本身不算状态流转
          render json: NoteSerializer.render_admin(note.reload), status: :created
        end

        def update
          authorize!("content:note:update")
          # 归属校验：非作者且非审核视角 → 403
          raise ForbiddenError, "无权限修改他人发布的内容" unless editable_by?(@note)

          previous_status = @note.status
          new_status = params[:status].presence
          updates = note_params.except(:status)
          content_changed = content_fields_changed?(updates)

          if new_status && new_status != previous_status
            # 显式改状态：只有审核视角能做，且必须写入审核流水
            authorize!("content:review:list")
            updates[:status] = new_status

            # 作者改自己的内容但指定了不同状态：拦下来
            if @note.user_id == current_user.id && !has_review_privilege?
              raise ForbiddenError, "作者不能手动修改审核状态，请走提交/撤回入口"
            end
          elsif content_changed && %w[published archived].include?(previous_status)
            # 已发布/已下架的内容被改了内容字段 → 强制重新审核
            updates[:status] = "pending"
          end

          @note.update!(updates)
          sync_tags(@note, params[:tags])

          # 写审核流水
          if updates[:status] && updates[:status] != previous_status
            review!(
              @note.reload,
              previous_status,
              updates[:status],
              action: new_status ? action_for_manual_change(previous_status, updates[:status]) : "auto_pending",
              reviewer: (new_status ? current_user : nil),
              reason: params[:reason].presence
            )
            # 通过/下架/重新发布时通知作者
            notify_review(@note, previous_status)
          end

          render json: NoteSerializer.render_admin(@note.reload)
        end

        def destroy
          authorize!("content:note:delete")
          raise ForbiddenError, "无权限删除他人发布的内容" unless deletable_by?(@note)

          @note.destroy!
          render json: { message: "删除成功" }
        end

        # POST /admin/notes/:id/submit —— 草稿/驳回 → 待审
        def submit
          authorize!("content:note:submit")
          raise ForbiddenError, "只能提交自己发布的内容" unless @note.user_id == current_user.id

          allowed = %w[draft rejected]
          raise ForbiddenError, "当前状态 #{@note.status} 不允许提交审核" unless allowed.include?(@note.status)

          previous = @note.status
          @note.update!(status: "pending")
          review!(@note, previous, "pending", action: "submit", reviewer: current_user)

          render json: NoteSerializer.render_admin(@note.reload)
        end

        # POST /admin/notes/:id/withdraw —— 待审 → 草稿（作者撤回）
        def withdraw
          authorize!("content:note:withdraw")
          raise ForbiddenError, "只能撤回自己发布的内容" unless @note.user_id == current_user.id

          raise ForbiddenError, "只有待审状态才能撤回" unless @note.pending?

          previous = @note.status
          @note.update!(status: "draft")
          review!(@note, previous, "draft", action: "withdraw", reviewer: current_user)

          render json: NoteSerializer.render_admin(@note.reload)
        end

        # GET /admin/notes/:id/reviews —— 审核历史时间线
        def reviews
          authorize!("content:review:history")
          # 归属校验：审核视角看全部；作者永远能看自己内容的审核历史——**跟内容当前状态无关**
          # 注意：这里不能用 editable_by?，因为 editable_by 包含了"published/archived 态作者不能编辑"
          # 的规则，而看历史≠编辑
          unless has_review_privilege? || @note.user_id == current_user.id
            raise ForbiddenError, "无权限查看他人内容的审核历史"
          end

          items = @note.note_reviews.timeline.map do |r|
            {
              id: r.id,
              action: r.action,
              from_status: Note::STATUSES.key(r.from_status),
              to_status: Note::STATUSES.key(r.to_status),
              reason: r.reason,
              # 脱敏规则：
              #   审核视角 → 全真实名；
              #   否则：reviewer 是当前用户自己 → 真实名，是别人（审核员）→ 脱敏
              reviewer_display: reviewer_display_for(r),
              created_at: r.created_at.iso8601
            }
          end

          render json: { items: items }
        end

        private

        def set_note
          @note = Note.find(params[:id])
        end

        # 每条流水的 reviewer 显示名：
        #   审核视角 → 全真实名（审核员自己的名字不会在审核队列里脱敏）
        #   普通注册用户：reviewer 是自己 → 真名；是别人（审核员）→ 脱敏
        def reviewer_display_for(review)
          return "系统" if review.reviewer.nil?
          return review.reviewer.name if has_review_privilege?
          return review.reviewer.name if review.reviewer == current_user

          "审核员 #{review.reviewer.id % 9 + 1}"
        end

        # 是否拥有审核视角：能看全部内容并绕过部分状态机。
        # 判定用 content:review:list（审核模块入口），不再是 content:note:review。
        def has_review_privilege?
          current_user.super_admin? || granted_codes.include?("content:review:list")
        end

        # 归属 + 状态机联合判定：谁能编辑这条内容
        def editable_by?(note)
          return true if has_review_privilege?

          return false unless note.user_id == current_user.id
          # 作者自己不能在 published/archived 态直接编辑（要么撤回要么等审核）
          return false if %w[published archived].include?(note.status)

          true
        end

        # 归属 + 状态机联合判定：谁能删除这条内容
        def deletable_by?(note)
          return true if has_review_privilege?

          return false unless note.user_id == current_user.id
          # 作者不能删除 archived（强制下架）的内容，防止把处罚结果抹掉
          return false if note.archived?

          true
        end

        # 对比 updates 里的内容字段和现有 note 是否有变化
        def content_fields_changed?(updates)
          CONTENT_FIELDS.any? do |key|
            next false unless updates.key?(key)

            old_val = @note.send(key)
            new_val = updates[key]
            # sections 数组要做深比较
            key == "sections" ? old_val != new_val : old_val != new_val
          end
        end

        # 根据状态流转选择审核流水的 action
        def action_for_manual_change(from, to)
          case [from, to]
          when %w[draft published], %w[rejected published], %w[pending published]
            "approve"
          when %w[* rejected]
            "reject"
          when %w[published archived]
            "archive"
          when %w[archived published]
            "restore"
          else
            "force_publish"
          end
        end

        # 写一条审核流水，from_status/to_status 存整数避免历史歧义
        def review!(note, from_status, to_status, action:, reviewer:, reason: nil)
          NoteReview.create!(
            note: note,
            from_status: from_status ? Note::STATUSES[from_status.to_sym] : nil,
            to_status: Note::STATUSES[to_status.to_sym],
            action: action,
            reviewer: reviewer,
            reason: reason
          )
        end

        def sync_tags(note, names)
          return if names.nil?

          cleaned = Array(names).map { |name| name.to_s.strip }.reject(&:empty?).uniq.first(10)
          note.tags = cleaned.map { |name| Tag.find_or_create_by!(name: name) }
        end

        def notify_review(note, previous_status)
          return unless %w[published archived].include?(note.status)
          return if previous_status == note.status

          NotificationJob.perform_later(user_id: note.user_id, action: "review", note_id: note.id)
        end

        def note_params
          params.permit(
            :title, :cover_url, :cover_ratio, :avatar_color, :channel, :sort, :content,
            sections: [
              :type, :duration, :completed, :title, :content,
              { images: [] },
              { origin: %i[lng lat name] },
              { destination: %i[lng lat name] }
            ]
          )
        end
      end
    end
  end
end
