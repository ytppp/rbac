require "rails_helper"

RSpec.describe "Token 续期", type: :request do
  let(:user) { create(:user) }

  describe "POST /api/v1/auth/refresh" do
    it "用 refresh token 换发新的一对 token" do
      refresh_token = JsonWebToken.encode_refresh(user.id)

      post "/api/v1/auth/refresh", params: { refresh_token: refresh_token }

      expect(response).to have_http_status(:ok)
      expect(json_body["access_token"]).to be_present
      expect(json_body["refresh_token"]).to be_present
      expect(json_body.dig("user", "id")).to eq(user.id)
    end

    it "无效的 refresh token 返回 401" do
      post "/api/v1/auth/refresh", params: { refresh_token: "not-a-token" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "被禁用的账号不能续期" do
      refresh_token = JsonWebToken.encode_refresh(user.id)
      user.update!(status: :disabled)

      post "/api/v1/auth/refresh", params: { refresh_token: refresh_token }

      expect(response).to have_http_status(:forbidden)
    end
  end

  it "refresh token 不能当作 access token 访问业务接口" do
    refresh_token = JsonWebToken.encode_refresh(user.id)

    get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{refresh_token}" }

    expect(response).to have_http_status(:unauthorized)
  end
end
