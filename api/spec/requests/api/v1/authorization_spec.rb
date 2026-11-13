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
      # 审核视角的判定已从 content:note:review 迁移到 content:review:list
      reviewer.roles << create(:role, code: "content_reviewer", permission_codes: %w[content:note:update content:review:list])
    end

    it "没有审核视角时不能修改审核状态" do
      patch "/api/v1/admin/notes/#{note.id}",
            params: { status: "published" },
            headers: auth_headers(editor),
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(note.reload.status).to eq("pending")
    end

    it "有审核视角时可以下架内容" do
      note.update!(status: :published)

      patch "/api/v1/admin/notes/#{note.id}",
            params: { status: "archived" },
            headers: auth_headers(reviewer),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(note.reload.status).to eq("archived")
    end
  end

  describe "审核历史（content:review:history）" do
    let(:author) { create(:user, role_codes: []) }
    let(:note) { create(:note, user: author, author_name: author.name, status: :draft) }

    before do
      # 不依赖 seeds 里的内置角色，测试库未必跑了 seeds，直接建一个带正确权限的角色
      author.roles << create(
        :role,
        code: "test_registered_user",
        permission_codes: %w[content:note:list content:review:history]
      )
    end

    it "注册用户作为作者可以看自己内容的审核历史" do
      get "/api/v1/admin/notes/#{note.id}/reviews", headers: auth_headers(author)
      expect(response).to have_http_status(:ok)
    end

    it "没有 content:review:history 权限时不能看审核历史" do
      bare = create(:user, role_codes: [])
      bare.roles << create(:role, code: "empty", permission_codes: %w[content:note:list])

      get "/api/v1/admin/notes/#{note.id}/reviews", headers: auth_headers(bare)
      expect(response).to have_http_status(:forbidden)
    end

    it "注册用户不能看他人内容的审核历史" do
      other_note = create(:note, status: :draft)

      get "/api/v1/admin/notes/#{other_note.id}/reviews", headers: auth_headers(author)
      expect(response).to have_http_status(:forbidden)
    end

    it "已发布的内容作者仍然能看自己内容的审核历史" do
      note.update!(status: :published)

      get "/api/v1/admin/notes/#{note.id}/reviews", headers: auth_headers(author)
      expect(response).to have_http_status(:ok)
    end
  end
end
