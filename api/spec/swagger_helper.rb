require "rails_helper"
require "rswag/specs"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Tracemark API V1",
        version: "v1",
        description: "内容社区与管理后台接口。除标注公开的接口外，均需 Bearer access token。"
      },
      servers: [
        { url: "http://localhost:3000/api/v1", description: "本地开发环境" }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: "JWT"
          }
        }
      },
      paths: {},
      tags: []
    }
  }

  config.openapi_format = :yaml
end
