require "rails_helper"

RSpec.describe "接口级权限校验", type: :request do
  let(:role) { create(:role, permission_codes: %w[system:user:list]) }
  let(:user) { create(:user, role_codes: []) }

  before { user.roles << role }

  it "拥有对应权限码时可以访问" do
    get "/api/v1/users", headers: auth_headers(user)

    expect(response).to have_http_status(:ok)
  end

  it "缺少权限码时返回 403" do
    delete "/api/v1/users/#{create(:user).id}", headers: auth_headers(user)

    expect(response).to have_http_status(:forbidden)
    expect(json_body["error"]).to include("system:user:delete")
  end

  it "超级管理员跳过权限校验" do
    admin = create(:user, role_codes: [Role::SUPER_ADMIN_CODE])

    get "/api/v1/users", headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
  end
end
