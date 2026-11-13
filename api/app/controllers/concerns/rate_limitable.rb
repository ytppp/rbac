# 简易限流：按「场景 + 客户端 IP」在时间窗口内计数，超过上限抛 429。
# 依赖 Rails.cache，生产环境请配置 redis 等共享缓存。
module RateLimitable
  extend ActiveSupport::Concern

  private

  def throttle!(key:, limit:, period:)
    # 测试环境不做限流，避免用例之间相互影响
    return if Rails.env.test?

    cache_key = "rate_limit:#{key}:#{request.remote_ip}"
    count = Rails.cache.increment(cache_key, 1, expires_in: period)
    if count.nil?
      Rails.cache.write(cache_key, 1, expires_in: period)
      count = 1
    end

    raise RateLimitedError, "操作太频繁，请稍后再试" if count > limit
  end
end
