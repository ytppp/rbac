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

  describe "内容审核权限" do
    let(:editor) { create(:user, role_codes: []) }
    let(:reviewer) { create(:user, role_codes: []) }
    let(:note) { create(:note, status: :pending) }

    before do
      editor.roles << create(:role, code: "content_editor", permission_codes: %w[content:note:update])
      reviewer.roles << create(:role, code: "content_reviewer", permission_codes: %w[content:note:update content:note:review])
    end

    it "没有 content:note:review 时不能修改状态" do
      patch "/api/v1/admin/notes/#{note.id}",
            params: { status: "published" },
            headers: auth_headers(editor),
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(note.reload.status).to eq("pending")
    end

    it "有 content:note:review 时可以下架内容" do
      note.update!(status: :published)

      patch "/api/v1/admin/notes/#{note.id}",
            params: { status: "archived" },
            headers: auth_headers(reviewer),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(note.reload.status).to eq("archived")
    end
  end
end
