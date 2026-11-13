require "lograge"
require "logstash-event"

# 结构化请求日志：把 Rails 默认的多行日志压成单行 JSON，ELK / Loki 可直接按字段解析。
Rails.application.configure do
  # 生产默认开启；开发 / 测试用 LOGRAGE_ENABLED=true 显式打开
  config.lograge.enabled = Rails.env.production? || ENV["LOGRAGE_ENABLED"] == "true"
  # 关闭 Rails 原始多行日志，避免同一次请求重复输出
  config.lograge.keep_original_rails_log = false
  # 纯 API 项目：控制器继承自 ActionController::API，必须显式挂上，
  # 否则 custom_payload 不会执行（user_id / request_id 会缺失）
  config.lograge.base_controller_class = ["ActionController::API", "ActionController::Base"]
  # Logstash formatter 输出 JSON（@timestamp / message / 自定义字段）
  config.lograge.formatter = Lograge::Formatters::Logstash.new

  # 固定字段：请求级信息
  config.lograge.custom_payload do |controller|
    {
      request_id: controller.request.request_id,
      user_id: controller.respond_to?(:current_user, true) ? controller.send(:current_user)&.id : nil,
      remote_ip: controller.request.remote_ip
    }
  end

  # 额外字段：过滤后的参数（密码等由 filter_parameters 去掉）
  config.lograge.custom_options = lambda do |event|
    params = ActiveSupport::ParameterFilter
      .new(Rails.application.config.filter_parameters)
      .filter(event.payload[:params] || {})
      .except("controller", "action", "format")

    { params: params }
  end
end
