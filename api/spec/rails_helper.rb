require "spec_helper"
# 强制测试环境：无论 Dockerfile / docker-compose 注入了什么 RAILS_ENV，
# 跑 RSpec 一律切到 test，避免开发库被污染、测试数据跑错库。
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods

  # 让 ActiveJob matchers（have_enqueued_job）可用
  ActiveJob::Base.queue_adapter = :test
end
