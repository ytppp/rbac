require "swagger_helper"

RSpec.describe "RBAC API V1", type: :request, swagger_doc: "v1/swagger.yaml" do
  let(:user) { create(:user) }

  path "/auth/login" do
    post "登录" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string }
        },
        required: %w[email password]
      }

      response "200", "登录成功，返回 access / refresh token" do
        let(:credentials) { { email: user.email, password: "Password@123" } }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["access_token"]).to be_present
          expect(body["refresh_token"]).to be_present
        end
      end

      response "401", "邮箱或密码错误" do
        let(:credentials) { { email: user.email, password: "wrong-password" } }

        run_test!
      end
    end
  end

  path "/auth/refresh" do
    post "刷新 token" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :refresh, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string }
        },
        required: %w[refresh_token]
      }

      response "200", "换发新的一对 token" do
        let(:refresh) { { refresh_token: JsonWebToken.encode_refresh(user.id) } }

        run_test!
      end

      response "401", "refresh token 无效" do
        let(:refresh) { { refresh_token: "invalid" } }

        run_test!
      end
    end
  end

  path "/notes" do
    get "内容列表" do
      tags "Notes"
      produces "application/json"
      parameter name: :page, in: :query, type: :integer, required: false, description: "页码"
      parameter name: :per_page, in: :query, type: :integer, required: false, description: "每页条数"

      response "200", "成功" do
        before { create_list(:note, 3) }

        run_test!
      end
    end
  end

  path "/notes/{id}" do
    get "内容详情" do
      tags "Notes"
      produces "application/json"
      parameter name: :id, in: :path, type: :integer, required: true

      response "200", "成功" do
        let(:id) { create(:note).id }

        run_test!
      end

      response "404", "内容不存在" do
        let(:id) { 0 }

        run_test!
      end
    end
  end

  path "/notes/{id}/reports" do
    post "举报内容" do
      tags "Reports"
      consumes "application/json"
      produces "application/json"
      security [bearer_auth: []]
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :report, in: :body, schema: {
        type: :object,
        properties: {
          reason: { type: :string, enum: Report::REASONS },
          detail: { type: :string }
        },
        required: %w[reason]
      }

      response "201", "举报成功" do
        let(:Authorization) { "Bearer #{JsonWebToken.encode_access(user.id)}" }
        let(:id) { create(:note).id }
        let(:report) { { reason: "spam" } }

        run_test!
      end
    end
  end
end
