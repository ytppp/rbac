# 已登录但缺少所需权限
#
# 和 AuthError 的区别（这是 401 和 403 的经典差异）：
#   AuthError      401 Unauthorized —— 我不知道你是谁（没登录 / token 过期）
#   ForbiddenError 403 Forbidden    —— 我知道你是谁，但你没资格做这件事
#
# 项目中所有的「无权限」都由 BaseController 的 authorize! / authorize_any!
# 以及各控制器里的守卫逻辑抛出这个异常。
class ForbiddenError < StandardError; end
