# 已登录但缺少所需权限，对应 HTTP 403。
# 由 BaseController 的 authorize! 等守卫逻辑抛出。
class ForbiddenError < StandardError; end
