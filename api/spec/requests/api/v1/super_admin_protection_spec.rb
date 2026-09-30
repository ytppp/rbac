require "rails_helper"

RSpec.describe "超级管理员账号保护", type: :request do
  let(:admin) { create(:user, role_codes: [Role::SUPER_ADMIN_CODE]) }
  let(:super_admin_role_id) { admin.roles.first.id }
  let(:manager) do
    create(:user).tap do |user|
      user.roles << create(:role, permission_codes: %w[system:user:list system:user:update system:user:delete])
    end
  end

  describe "非超级管理员操作超级管理员账号" do
    it "不能编辑" do
      patch "/api/v1/users/#{admin.id}", params: { name: "被改名" }, headers: auth_headers(manager)

      expect(response).to have_http_status(:forbidden)
      expect(admin.reload.name).not_to eq("被改名")
    end

    it "不能禁用" do
      patch "/api/v1/users/#{admin.id}/status", params: { status: 0 }, headers: auth_headers(manager)

      expect(response).to have_http_status(:forbidden)
      expect(admin.reload).to be_enabled
    end

    it "不能重置密码" do
      patch "/api/v1/users/#{admin.id}/password",
            params: { password: "NewPass@123", password_confirmation: "NewPass@123" },
            headers: auth_headers(manager)

      expect(response).to have_http_status(:forbidden)
    end

    it "不能删除" do
      delete "/api/v1/users/#{admin.id}", headers: auth_headers(manager)

      expect(response).to have_http_status(:forbidden)
      expect(User.exists?(admin.id)).to be true
    end

    it "可以正常查看" do
      visible_ids = [admin.id, manager.id]

      get "/api/v1/users", headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(json_body["items"].map { |item| item["id"] }).to include(*visible_ids)
    end

    it "仍可正常编辑普通账号" do
      target = create(:user)

      patch "/api/v1/users/#{target.id}", params: { name: "正常改名" }, headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(target.reload.name).to eq("正常改名")
    end
  end

  describe "越权提权" do
    it "不能通过编辑把超级管理员角色分配给他人" do
      target = create(:user)

      patch "/api/v1/users/#{target.id}", params: { role_ids: [super_admin_role_id] }, headers: auth_headers(manager)

      expect(response).to have_http_status(:forbidden)
      expect(target.reload.super_admin?).to be false
    end

    it "不能新增超级管理员账号" do
      post "/api/v1/users",
           params: {
             email: "newadmin@example.com",
             name: "新超管",
             password: "Password@123",
             role_ids: [super_admin_role_id]
           },
           headers: auth_headers(manager)

      expect(response).to have_http_status(:forbidden)
      expect(User.exists?(email: "newadmin@example.com")).to be false
    end

    it "角色下拉不返回超级管理员角色" do
      admin

      get "/api/v1/roles/options", headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(json_body["items"].map { |item| item["code"] }).not_to include(Role::SUPER_ADMIN_CODE)
    end

    it "角色下拉对超级管理员本人仍需返回超级管理员角色" do
      get "/api/v1/roles/options", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(json_body["items"].map { |item| item["code"] }).to include(Role::SUPER_ADMIN_CODE)
    end
  end

  describe "超级管理员本人" do
    it "可以操作其他超级管理员账号" do
      another_admin = create(:user, role_codes: [Role::SUPER_ADMIN_CODE])

      patch "/api/v1/users/#{another_admin.id}", params: { name: "超管改名" }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(another_admin.reload.name).to eq("超管改名")
    end
  end
end
