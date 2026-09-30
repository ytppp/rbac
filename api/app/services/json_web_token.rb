require "jwt"

# JWT（JSON Web Token）的签发与校验。
#
# 为什么不用传统的 session？
#   这是纯 API 后端，前端可能是浏览器、也可能是 App，
#   把「你是谁」打包成一个签过名的字符串交给前端自己保管，
#   后端不用存 session，每次请求解一下 token 就知道是谁。
#
# token 长这样：xxx.yyy.zzz，三段用点隔开，
# 其中第二段是明文可读的（这里存了 user_id），
# 所以「不能放密码等机密信息」；但第三段是签名，改一个字符都会校验失败。
class JsonWebToken
  # 签名算法。HS256 表示「用同一个密钥做签名和验证」（对称加密），
  # 够用且实现简单；生产环境改造时也可换成 RS256（公私钥）。
  ALGORITHM = "HS256".freeze

  class << self
    # 签名用的密钥。优先读环境变量 JWT_SECRET；
    # 没配置就退回 Rails 自带的 secret_key_base，保证开发环境也能跑起来。
    def secret_key
      ENV["JWT_SECRET"].presence || Rails.application.secret_key_base
    end

    # 有效期。.to_i 把环境变量（字符串）转成整数，.hours 是 Rails 的时长方法，
    # 于是 "12".to_i.hours 得到「12 小时」这个时长对象。
    def expire_in
      ENV.fetch("JWT_EXPIRE_HOURS", 12).to_i.hours
    end

    # 签发 token：把 user_id 和过期时间打包签名
    def encode(user_id)
      now = Time.current
      payload = {
        user_id: user_id,
        # iat = issued at，签发时间；exp = expiration，过期时间。都是 Unix 时间戳（整数秒）
        iat: now.to_i,
        exp: (now + expire_in).to_i
      }
      JWT.encode(payload, secret_key, ALGORITHM)
    end

    # 校验并解析 token，返回里面的 payload
    def decode(token)
      # JWT.decode 返回 [payload, header]，这里只关心第一个，
      # 逗号后面的空变量是 Ruby 的「忽略这个位置」写法。
      # 第二个参数 true 表示「必须校验签名」。
      body, = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)
      # with_indifferent_access 让这个 Hash 的键既能用字符串也能用符号访问
      # （形如 payload[:user_id] 和 payload["user_id"] 都能取到值）
      body.with_indifferent_access
    rescue JWT::ExpiredSignature
      # 把第三方 gem 的异常翻译成自己项目里的 AuthError，
      # 这样控制器层不用认识 JWT 这个库，只认识 AuthError 就够了。
      raise AuthError, "登录已过期，请重新登录"
    rescue JWT::DecodeError
      # 签名不对、格式乱、被篡改，都归到这一类
      raise AuthError, "登录凭证无效，请重新登录"
    end
  end
end
