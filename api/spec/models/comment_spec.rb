require "rails_helper"

RSpec.describe Comment, type: :model do
  let(:note) { create(:note) }
  let(:user) { create(:user) }

  it "content 必填且最长 500" do
    expect(build(:comment, note: note, user: user, content: "")).not_to be_valid
    expect(build(:comment, note: note, user: user, content: "a" * 501)).not_to be_valid
    expect(build(:comment, note: note, user: user, content: "正常评论")).to be_valid
  end

  it "回复必须挂在本条内容的顶层评论下" do
    other_note = create(:note)
    parent = create(:comment, note: other_note)

    reply = build(:comment, note: note, user: user, parent: parent)

    expect(reply).not_to be_valid
    expect(reply.errors[:parent_id]).to be_present
  end

  it "不能回复一条回复" do
    root = create(:comment, note: note)
    reply = create(:comment, note: note, parent: root)

    child = build(:comment, note: note, parent: reply)

    expect(child).not_to be_valid
  end

  it "roots 只返回顶层评论" do
    root = create(:comment, note: note)
    create(:comment, note: note, parent: root)

    expect(Comment.where(note: note).roots).to contain_exactly(root)
  end

  it "oldest_first 按创建时间正序" do
    first = create(:comment, note: note, created_at: 2.hours.ago)
    second = create(:comment, note: note, created_at: 1.hour.ago)

    expect(Comment.where(note: note).oldest_first).to eq([first, second])
  end

  it "创建后给内容作者投递通知任务" do
    author = create(:user)
    note.update!(user: author)

    expect {
      create(:comment, note: note, user: user)
    }.to have_enqueued_job(NotificationJob)
  end
end
