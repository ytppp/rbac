# 审核流水：记录 notes 每次状态变更的前后态、操作人、驳回原因。
# 同一 note 可以有多条 review，按 created_at 升序就是完整审核链路。
class NoteReview < ApplicationRecord
  # 动作语义，枚举化避免拼写污染
  ACTIONS = %w[
    submit          # 作者提交草稿/驳回 → 待审
    approve         # 审核通过
    reject          # 审核驳回
    withdraw        # 作者撤回待审 → 草稿
    auto_pending    # 已发布内容变更，系统自动打回待审
    archive         # 超管/审核强制下架
    restore         # 超管/审核将 archived 重新发布
    force_publish   # 超管绕过审核直接发布（需写入 reason）
  ].freeze

  belongs_to :note
  belongs_to :reviewer, class_name: "User", optional: true

  # from_status 允许 nil，表示「从无状态而来」（比如首次创建记录）
  validates :from_status, allow_nil: true, numericality: { only_integer: true }
  validates :to_status,   presence: true,  numericality: { only_integer: true }
  validates :action,      presence: true, inclusion: { in: ACTIONS }
  validates :reason,      presence: true, if: -> { action == "reject" || action == "force_publish" }

  scope :timeline, -> { order(created_at: :asc, id: :asc) }

  # 给前端用的脱敏名称：作者侧永远只能看到「审核员 + N」，
  # 审核侧/超管看真实姓名。不在模型层分支，在序列化时按权限决定。
  def reviewer_display_name(is_reviewer:)
    return "系统" if reviewer.nil?

    is_reviewer ? reviewer.name : "审核员 #{reviewer.id % 9 + 1}"
  end
end
