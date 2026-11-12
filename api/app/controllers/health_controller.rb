# 容器健康检查：只验证进程存活与数据库连接，不做鉴权。
class HealthController < ActionController::API
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ok" }
  rescue StandardError => e
    render json: { status: "error", error: e.class.name }, status: :service_unavailable
  end
end
