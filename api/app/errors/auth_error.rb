# 未登录 / token 失效。
# BaseController 通过 rescue_from 统一转为 401 响应。
class AuthError < StandardError; end
