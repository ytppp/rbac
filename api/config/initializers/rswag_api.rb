Rswag::Api.configure do |config|
  # openapi 文件放在 api/swagger 下，由 rake rswag:specs:swaggerize 生成
  config.openapi_root = Rails.root.join("swagger").to_s
end
