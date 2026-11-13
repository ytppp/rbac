class FixReportsNoteUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    # 旧的 (note_id, user_id) 唯一索引会把「举报评论」也算成重复举报内容，
    # 改为只约束内容举报（comment_id 为空时）。
    remove_index :reports, name: "index_reports_on_note_id_and_user_id"
    add_index :reports, [ :note_id, :user_id ],
              unique: true,
              where: "comment_id IS NULL",
              name: "index_reports_on_note_only"
  end
end
