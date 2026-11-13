# 请求过于频繁：由 RateLimitable 抛出，统一返回 429
class RateLimitedError < StandardError; end
