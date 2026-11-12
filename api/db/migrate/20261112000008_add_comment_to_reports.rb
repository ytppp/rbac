class AddCommentToReports < ActiveRecord::Migration[7.1]
  def change
    # 举报对象可以是内容，也可以是评论：两者都存在时以评论为准
    change_column_null :reports, :note_id, true
    add_column :reports, :comment_id, :bigint

    add_index :reports, :comment_id
    add_index :reports, [ :comment_id, :user_id ], unique: true
    add_foreign_key :reports, :comments, on_delete: :cascade
  end
end
