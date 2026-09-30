require_relative "boot"

# 下面这些 require 是「按需加载 Rails 的各个模块」。
# 只 require 用得到的，能少加载一堆代码、启动更快。
require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"        # 数据库 ORM
require "action_controller/railtie"    # 控制器 / 路由
require "action_mailer/railtie"
require "action_view/railtie"

# 读取 Gemfile，把里面的 gem 自动加载进来
Bundler.require(*Rails.groups)

module RbacAdmin
  class Application < Rails::Application
    # 加载 Rails 7.1 的默认配置（框架推荐的一套默认值，升级时保持行为一致）
    config.load_defaults 7.1

    # 纯 API 模式：不加载 view / asset / session / cookie 中间件。
    # 因为本项目只返回 JSON，不需要渲染 HTML 模板，也不需要浏览器 session。
    config.api_only = true

    # 业务时区统一使用北京时间，数据库仍存 UTC。
    # 两者分开设置是常见做法：存 UTC 便于跨时区协作，展示时按业务时区来。
    config.time_zone = "Beijing"
    config.active_record.default_timezone = :utc

    # 生成器配置：以后用 rails generate 生成代码时的默认选项
    config.generators do |g|
      # 默认用 rspec 写测试，并且不生成 fixture / view spec / routing spec
      g.test_framework :rspec, fixture: false, view_specs: false, routing_specs: false
      g.helper false   # 不生成 helper（纯 API 不需要）
      g.assets false   # 不生成 assets（纯 API 不需要）
    end
  end
end
