require "rails_helper"

RSpec.describe Report, type: :model do
  let(:user) { create(:user) }
  let(:note) { create(:note) }

  it "reason 必填且必须在允许范围内" do
    expect(build(:report, user: user, note: note, reason: "")).not_to be_valid
    expect(build(:report, user: user, note: note, reason: "unknown")).not_to be_valid
    expect(build(:report, user: user, note: note, reason: "spam")).to be_valid
  end

  it "举报对象不能同时为空" do
    report = build(:report, user: user, note: nil, comment: nil)

    expect(report).not_to be_valid
    expect(report.errors[:base]).to include("举报对象不能为空")
  end

  it "同一用户不能重复举报同一内容" do
    create(:report, user: user, note: note)

    expect(build(:report, user: user, note: note)).not_to be_valid
  end

  it "不同用户可以举报同一内容" do
    create(:report, user: user, note: note)

    expect(build(:report, user: create(:user), note: note)).to be_valid
  end

  it "同一用户不能重复举报同一评论" do
    comment = create(:comment, note: note)
    create(:report, :comment, user: user, comment: comment)

    expect(build(:report, :comment, user: user, comment: comment)).not_to be_valid
  end

  it "举报过内容后仍可举报该内容下的评论" do
    comment = create(:comment, note: note)
    create(:report, user: user, note: note)

    expect(build(:report, :comment, user: user, comment: comment)).to be_valid
  end

  it "状态只接受枚举值" do
    report = create(:report)
    report.status = "bogus"

    expect(report).not_to be_valid
  end

  it "默认状态为待处理" do
    expect(create(:report).status).to eq("pending")
  end
end
