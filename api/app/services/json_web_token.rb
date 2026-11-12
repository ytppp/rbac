require "jwt"

# JWT 的签发与校验。
# payload 明文可读，不能存放机密信息。
#
# 两类 token：
#   access  —— 短期（默认 2 小时），随每次请求放在 Authorization 头里
#   refresh —— 长期（默认 7 天），只用于换新的 access token，不能访问业务接口
class JsonWebToken
  ALGORITHM = "HS256".freeze
  ACCESS_TYPE = "access".freeze
  REFRESH_TYPE = "refresh".freeze

  class << self
    # 密钥优先取环境变量，未配置时回退 secret_key_base
    def secret_key
      ENV["JWT_SECRET"].presence || Rails.application.secret_key_base
    end

    def access_expire_in
      ENV.fetch("JWT_ACCESS_EXPIRE_HOURS", 2).to_i.hours
    end

    def refresh_expire_in
      ENV.fetch("JWT_REFRESH_EXPIRE_DAYS", 7).to_i.days
    end

    # 兼容旧调用：默认签发 access token
    def expire_in
      access_expire_in
    end

    def encode(user_id)
      encode_access(user_id)
    end

    def encode_access(user_id)
      build_token(user_id, type: ACCESS_TYPE, ttl: access_expire_in)
    end

    def encode_refresh(user_id)
      build_token(user_id, type: REFRESH_TYPE, ttl: refresh_expire_in)
    end

    def decode(token, type: ACCESS_TYPE)
      body, = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)
      payload = body.with_indifferent_access

      # refresh token 不能当 access token 用，反之亦然
      raise AuthError, "登录凭证类型不正确" unless payload[:type] == type

      payload
    rescue JWT::ExpiredSignature
      # 统一翻译成项目的 AuthError，控制器层无需认识 JWT 库
      raise AuthError, "登录已过期，请重新登录"
    rescue JWT::DecodeError
      raise AuthError, "登录凭证无效，请重新登录"
    end

    private

    def build_token(user_id, type:, ttl:)
      now = Time.current
      payload = {
        user_id: user_id,
        type: type,
        jti: SecureRandom.uuid,
        iat: now.to_i,
        exp: (now + ttl).to_i
      }
      JWT.encode(payload, secret_key, ALGORITHM)
    end
  end
end
