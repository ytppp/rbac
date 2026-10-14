require "jwt"

# JWT 的签发与校验。
# payload 明文可读，不能存放机密信息。
class JsonWebToken
  ALGORITHM = "HS256".freeze

  class << self
    # 密钥优先取环境变量，未配置时回退 secret_key_base
    def secret_key
      ENV["JWT_SECRET"].presence || Rails.application.secret_key_base
    end

    def expire_in
      ENV.fetch("JWT_EXPIRE_HOURS", 12).to_i.hours
    end

    def encode(user_id)
      now = Time.current
      payload = {
        user_id: user_id,
        iat: now.to_i,
        exp: (now + expire_in).to_i
      }
      JWT.encode(payload, secret_key, ALGORITHM)
    end

    def decode(token)
      body, = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)
      body.with_indifferent_access
    rescue JWT::ExpiredSignature
      # 统一翻译成项目的 AuthError，控制器层无需认识 JWT 库
      raise AuthError, "登录已过期，请重新登录"
    rescue JWT::DecodeError
      raise AuthError, "登录凭证无效，请重新登录"
    end
  end
end
