require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "admin@example.com", password: "Admin@123456") }

    it "邮箱密码正确时返回 token 与权限码" do
      post "/api/v1/auth/login", params: { email: "admin@example.com", password: "Admin@123456" }

      expect(response).to have_http_status(:ok)
      expect(json_body["token"]).to be_present
      expect(json_body["user"]["email"]).to eq("admin@example.com")
      expect(json_body).to have_key("permissions")
    end

    it "密码错误时返回 401" do
      post "/api/v1/auth/login", params: { email: "admin@example.com", password: "wrong-password" }

      expect(response).to have_http_status(:unauthorized)
      expect(json_body["error"]).to eq("邮箱或密码错误")
    end

    it "账号被禁用时返回 403" do
      user.update!(status: :disabled)

      post "/api/v1/auth/login", params: { email: "admin@example.com", password: "Admin@123456" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/auth/me" do
    let(:user) { create(:user) }

    it "未携带 token 时返回 401" do
      get "/api/v1/auth/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "携带有效 token 时返回当前用户" do
      get "/api/v1/auth/me", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json_body["user"]["id"]).to eq(user.id)
    end
  end
end
