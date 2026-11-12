require "rails_helper"

RSpec.describe "注册接口", type: :request do
  let(:payload) do
    {
      name: "新用户",
      email: "newbie@example.com",
      password: "secret123",
      password_confirmation: "secret123"
    }
  end

  before do
    create(:role, code: Role::REGISTERED_USER_CODE, name: "注册用户")
  end

  it "注册成功后直接返回登录态" do
    post "/api/v1/auth/register", params: payload, as: :json

    expect(response).to have_http_status(:created)
    expect(json_body["access_token"]).to be_present
    expect(json_body["refresh_token"]).to be_present
    expect(json_body.dig("user", "email")).to eq("newbie@example.com")
  end

  it "注册用户自动获得注册用户角色" do
    post "/api/v1/auth/register", params: payload, as: :json

    user = User.find_by(email: "newbie@example.com")
    expect(user.role_codes).to include(Role::REGISTERED_USER_CODE)
  end

  it "邮箱重复时返回 422" do
    create(:user, email: "newbie@example.com")

    post "/api/v1/auth/register", params: payload, as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "两次密码不一致时返回 422" do
    post "/api/v1/auth/register", params: payload.merge(password_confirmation: "mismatch"), as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "昵称为空时返回 422" do
    post "/api/v1/auth/register", params: payload.merge(name: ""), as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end
end
