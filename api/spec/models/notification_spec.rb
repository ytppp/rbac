require "rails_helper"

RSpec.describe Notification, type: :model do
  let(:user) { create(:user) }
  let(:actor) { create(:user) }

  it "action 必须在允许范围内" do
    expect(build(:notification, user: user, action: "unknown")).not_to be_valid
    expect(build(:notification, user: user, action: "like")).to be_valid
  end

  describe ".push" do
    it "不给自己发通知" do
      expect {
        Notification.push(user_id: user.id, actor_id: user.id, action: "comment")
      }.not_to change(Notification, :count)
    end

    it "user_id 为空时不创建" do
      expect {
        Notification.push(user_id: nil, actor_id: actor.id, action: "comment")
      }.not_to change(Notification, :count)
    end

    it "正常创建通知" do
      expect {
        Notification.push(user_id: user.id, actor_id: actor.id, action: "comment", note_id: nil)
      }.to change(Notification, :count).by(1)
    end
  end

  it "unread 只返回未读通知" do
    unread = create(:notification, user: user)
    create(:notification, user: user, read_at: Time.current)

    expect(Notification.where(user: user).unread).to contain_exactly(unread)
  end

  it "recent 按创建时间倒序" do
    older = create(:notification, user: user, created_at: 2.hours.ago)
    newer = create(:notification, user: user, created_at: 1.hour.ago)

    expect(Notification.where(user: user).recent).to eq([newer, older])
  end
end
