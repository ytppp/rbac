# Sidekiq 连接配置：docker-compose 里起一个 redis 服务，默认 host=redis port=6379
# gem 用 require: false，只有设了 REDIS_URL 才加载
if ENV["REDIS_URL"].present?
  require "sidekiq"
  require "redis"

  Sidekiq.configure_server do |config|
    config.redis = { url: ENV["REDIS_URL"] }
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: ENV["REDIS_URL"] }
  end
end
