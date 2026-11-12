require "rails_helper"

RSpec.describe "内容互动接口", type: :request do
  let(:user) { create(:user) }
  let(:note) { create(:note, user: user, likes_count: 0) }

  describe "点赞 / 取消点赞" do
    it "未登录时返回 401" do
      post "/api/v1/notes/#{note.id}/like"

      expect(response).to have_http_status(:unauthorized)
    end

    it "点赞后计数加一，重复点赞保持幂等" do
      post "/api/v1/notes/#{note.id}/like", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json_body["liked"]).to be(true)
      expect(note.reload.likes_count).to eq(1)

      post "/api/v1/notes/#{note.id}/like", headers: auth_headers(user)
      expect(note.reload.likes_count).to eq(1)
    end

    it "取消点赞后计数归零" do
      post "/api/v1/notes/#{note.id}/like", headers: auth_headers(user)
      delete "/api/v1/notes/#{note.id}/unlike", headers: auth_headers(user)

      expect(json_body["liked"]).to be(false)
      expect(note.reload.likes_count).to eq(0)
    end
  end

  describe "收藏" do
    it "收藏后详情接口返回 favorited" do
      post "/api/v1/notes/#{note.id}/favorite", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)

      get "/api/v1/notes/#{note.id}", headers: auth_headers(user)
      expect(json_body["favorited"]).to be(true)
    end
  end

  describe "评论" do
    it "发表评论后出现在列表里" do
      post "/api/v1/notes/#{note.id}/comments",
           params: { content: "写得好" },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:created)

      get "/api/v1/notes/#{note.id}/comments"
      expect(json_body["items"].first["content"]).to eq("写得好")
      expect(json_body["total"]).to eq(1)
    end

    it "未登录时不能评论" do
      post "/api/v1/notes/#{note.id}/comments", params: { content: "匿名" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "已下架内容" do
    it "app 端不可见" do
      note.update!(status: :archived)

      get "/api/v1/notes/#{note.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
