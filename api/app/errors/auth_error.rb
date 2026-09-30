# 未登录 / token 失效
#
# 这是一个「自定义异常类」。它继承了 Ruby 内置的 StandardError，
# 所以可以像普通异常一样 `raise AuthError, "提示信息"` 抛出来。
#
# 为什么要有自定义异常，而不是直接用 StandardError？
#   因为它可以被精确识别：BaseController 里写了
#     rescue_from AuthError, with: :render_unauthorized
#   于是「哪里抛出 AuthError」和「返回 401」这两件事就解耦了 ——
#   抛的地方只管抛，转 HTTP 响应的地方只管转，中间不用互相知道。
#
# 类体是空的（只有一行 end），因为这里只需要一个「类型标记」，
# 具体行为（怎么变成响应）交给控制器处理。
class AuthError < StandardError; end
