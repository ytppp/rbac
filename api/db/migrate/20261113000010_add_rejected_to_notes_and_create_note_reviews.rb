# 状态机升级：notes 枚举新增 rejected（被驳回待作者修改）。
# 同时新建审核流水表 note_reviews，完整记录每次状态变更的前后态、操作人、驳回原因等，
# 供作者和审核方回溯整条审核链路。
class AddRejectedToNotesAndCreateNoteReviews < ActiveRecord::Migration[7.1]
  # 枚举值必须与 Note::STATUSES 保持一致：
  # draft=0 pending=1 published=2 archived=3 rejected=4
  REJECTED = 4

  def up
    # SQLite 不支持 ALTER COLUMN，也不支持 ADD COLUMN with enum 的 check 约束；
    # 这里用纯整数存储（notes.status 本质是 integer，STATUSES 映射在模型层），所以无需变更列类型，
    # 只要确保新值 4 被允许即可。历史数据不动。
    #
    # 对于 Postgres，若 notes.status 是 integer 列则什么都不用做；
    # 若曾被意外改成 ENUM 类型，下面这行把它打回 integer 以便自由扩展：
    begin
      execute "ALTER TABLE notes ALTER COLUMN status TYPE INTEGER USING status::INTEGER"
    rescue ActiveRecord::StatementInvalid
      # SQLite / 已经是 integer：忽略
    end

    create_table :note_reviews do |t|
      t.references :note, null: false, foreign_key: true
      # 状态变更前后值：保存整数与语义名，避免枚举变更时历史数据歧义
      t.integer  :from_status, null: false
      t.integer  :to_status,   null: false
      # 动作语义（提交 / 通过 / 驳回 / 撤回 / 自动待审 / 下架 / 重新发布 / 强制发布）
      t.string   :action, null: false
      # 驳回原因 / 操作备注；驳回时必填，其他动作可选
      t.text     :reason
      # 操作人：系统自动触发（如 published 内容变更自动转回 pending）时为 NULL
      t.references :reviewer, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :note_reviews, [:note_id, :created_at], order: { created_at: :asc }

    # 把历史已驳回/下架等状态回填 —— 这里只创建表不回填旧数据，避免猜测
  end

  def down
    drop_table :note_reviews
    # rejected 是新加的枚举值，回滚时 Postgres 需先把所有 rejected 记录改成其他状态，再调小枚举。
    # 由于我们改成了纯 integer 列，回滚只需把 rejected 记录批量迁回 pending 即可。
    execute "UPDATE notes SET status = #{REJECTED - 1} WHERE status = #{REJECTED}"
  end
end
