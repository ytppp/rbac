class ApplicationJob < ActiveJob::Base
  # 默认重试两次后丢弃；Sidekiq 环境下走其自带的重试机制
  retry_on StandardError, wait: :polynomially_longer, attempts: 2
end
