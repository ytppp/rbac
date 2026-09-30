# 统一 JSON 错误响应格式：把未被控制器捕获的异常收敛为结构化输出
# 注意：控制器内的业务异常已由 Api::V1::BaseController 的 rescue_from 处理
Rails.application.config.exceptions_app = lambda do |env|
  exception = env["action_dispatch.exception"]

  status =
    case exception
    when ActionController::RoutingError,
         ActiveRecord::RecordNotFound,
         ActionController::UnknownFormat
      404
    when ActionController::ParameterMissing, ActionController::BadRequest
      400
    when ActionController::MethodNotAllowed
      405
    when ActionController::NotImplemented
      501
    else
      500
    end

  message =
    case status
    when 404 then "资源不存在"
    when 400 then "请求参数有误"
    when 405 then "请求方法不被允许"
    else "服务器内部错误"
    end

  body = { error: message }.to_json
  headers = {
    "Content-Type" => "application/json; charset=utf-8",
    "Content-Length" => body.bytesize.to_s
  }

  [status, headers, [body]]
end
