# 内容详情页需要的字段：正文（Markdown）与分段行程（含每段图片）。
# sections 是 JSONB 数组，每项形如：
#   { type: "plane|driving|walking|none", origin: {lng, lat, name}, destination: {...},
#     duration: 8100, completed: true, images: ["..."] }
class AddDetailFieldsToNotes < ActiveRecord::Migration[7.1]
  def change
    add_column :notes, :content, :text, default: "", null: false
    add_column :notes, :sections, :jsonb, default: [], null: false
  end
end
