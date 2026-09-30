Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # 开发环境允许本地前端；生产环境通过 CORS_ORIGINS 环境变量配置白名单
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:5173").split(",").map(&:strip))

    resource "*",
             headers: :any,
             expose: %w[Authorization],
             methods: %i[get post put patch delete options head],
             max_age: 86_400
  end
end
