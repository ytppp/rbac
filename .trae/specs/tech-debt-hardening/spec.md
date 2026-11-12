# 技术债清理：测试 / SSR / 日志 / API 文档 / 安全 / Docker

## 目标
一次性落实上一轮「长期技术债」建议中的 6 项，保持现有 41 个 RSpec 用例全绿，且不破坏 app（Nuxt）与 admin（Vite）现有登录流程。

## 范围与决定

### 1. 测试：补高风险模型 spec
新增/修改文件：
- `api/spec/factories/all.rb`：新增 `comment`、`report`、`notification` 三个 factory；`comment` 关联 `note`/`user`，`report` 关联 `user` 并支持 `note` / `comment` 两种目标，`notification` 关联 `user`。
- `api/spec/models/report_spec.rb`
  - reason 必填、必须在 `REASONS` 内
  - `note_id` 与 `comment_id` 同时为空 → 校验失败（`target_must_exist`）
  - 同一用户对同一内容重复举报 → 失败；不同用户可重复
  - 同一用户对同一评论重复举报 → 失败
  - 对内容已举报后再举报该内容的评论 → 允许（验证条件唯一索引语义）
  - `status` 枚举校验（非法值不写入）
- `api/spec/models/comment_spec.rb`
  - content 必填、最大 500
  - 回复必须挂在本条内容下的顶层评论（父级是回复 / 跨内容 → 失败）
  - `roots` / `oldest_first` scope 行为
  - 创建后向内容作者投递 `NotificationJob`（用 ActiveJob test adapter 断言 enqueued）
- `api/spec/models/notification_spec.rb`
  - action 必须在 `ACTIONS` 内
  - `Notification.push`：user_id 为空或 actor==user 时不创建
  - 正常创建；`unread` 只返回 read_at 为空的；`recent` 倒序
- `api/config/environments/test.rb`：`config.active_job.queue_adapter = :test`，避免测试真的往 Redis/Sidekiq 投递。

### 2. SSR：explore 详情页缓存
- `app/nuxt.config.ts` 增加：
  - `routeRules: { '/explore/**': { swr: 60 }, '/en/explore/**': { swr: 60 } }`
  - 说明：缓存 60 秒 + stale-while-revalidate，HTML 由 Nitro 缓存，过期后后台重建。
- `app/app/pages/explore/[id].vue`
  - SSR 阶段请求详情不带 `Authorization`（避免把某个用户的点赞/收藏状态写进公共缓存）：`headers: import.meta.server ? {} : authHeaders()`。
  - 用 `useState` 记录「本次首屏是 SSR 且需要在客户端补拉个人状态」，`onMounted` 时若已登录则 `refresh()` 并同步 `favorited`；客户端路由跳转不额外请求。
- 不改动列表页 `/explore` 的缓存（列表含个人 liked 状态，缓存会串号），只在回答中说明原因。

### 3. 日志：lograge + logstash formatter
- `api/Gemfile` 增加 `gem "lograge"`、`gem "logstash-event"`（都 `require: false` 交给 initializer 加载）。
- 新增 `api/config/initializers/lograge.rb`
  - `config.lograge.enabled = Rails.env.production? || ENV["LOGRAGE_ENABLED"] == "true"`
  - `config.lograge.formatter = Lograge::Formatters::Logstash.new`（单行 JSON）
  - `custom_options`：`request_id`、`user_id`（从 `@current_user` 取）、`remote_ip`、`params`（用 `ActiveSupport::ParameterFilter` + `Rails.application.config.filter_parameters` 过滤密码等）
  - `keep_original_rails_log = false`
- `api/config/environments/production.rb` 删除 `config.log_tags = [:request_id]`（tag 会拼在 JSON 前，破坏「直接可解析」），request_id 改由 `custom_options` 输出。
- `docker-compose.yml` 给 api / sidekiq 加 `LOGRAGE_ENABLED: "true"`，开发环境也能看到结构化日志。

### 4. API 文档：rswag
- `api/Gemfile`：默认组加 `rswag-api`、`rswag-ui`；development/test 组加 `rswag-specs`。
- 新增 `api/config/initializers/rswag_api.rb`（openapi_root `swagger/v1`）与 `rswag_ui.rb`（Swagger UI）。
- `api/config/routes.rb` mount：`/api-docs`（Ui）与 `/api-docs/v1`（Api）。
- 新增 `api/spec/swagger_helper.rb`：OpenAPI 3.0.1 基本信息 + `bearer_auth` security scheme。
- 新增 `api/spec/requests/api/v1/swagger_spec.rb`，覆盖核心接口：
  - `POST /auth/login`（200 / 401）
  - `POST /auth/refresh`（200 / 401）
  - `GET /notes`、`GET /notes/{id}`
  - `POST /notes/{id}/reports`（需登录）
- 生成 `api/swagger/v1/swagger.yaml`（`bundle exec rake rswag:specs:swaggerize`）。
- 文档默认可公开访问；如不希望生产暴露，用 `ENV["API_DOCS_ENABLED"]` 控制 mount（默认开启开发/测试，生产需显式开启）。

### 5. 安全：access token 短效 + refresh token 长效
- `api/app/services/json_web_token.rb`
  - access：默认 2 小时，`ENV["JWT_ACCESS_EXPIRE_HOURS"]`；refresh：默认 7 天，`ENV["JWT_REFRESH_EXPIRE_DAYS"]`。
  - payload 增加 `type: "access" | "refresh"` 与随机 `jti`。
  - `decode(token, type: :access)` 校验类型，refresh token 不能当 access 用（抛 `AuthError`）。
  - 保留 `encode` 作为 `encode_access` 的别名，减少既有测试改动面（`spec/support/auth_helpers.rb` 仍可用）。
- `api/app/controllers/api/v1/auth_controller.rb`
  - `session_payload` 返回 `access_token`、`refresh_token`、`expires_in`（access 有效期）、user/roles/permissions；移除 `token`。
  - 新增 `POST /api/v1/auth/refresh`：接收 `refresh_token`，校验类型与用户状态，签发新的一对 token（轮换）。
  - `login/register` 仍做限流；refresh 也做限流（key `auth/refresh`，20 次/分钟）。
- `api/config/routes.rb` 增加 `post "auth/refresh"`。
- app 端：
  - `app/app/composables/useAuth.ts`：cookie 改为 `community_access_token`（2h）与 `community_refresh_token`（7d）；`applySession` 读 `access_token`/`refresh_token`；新增 `refreshSession()`。
  - `app/app/composables/useApiFetch.ts`：401 时先 refresh 再重放一次（不无限重试），失败才 logout + 跳登录。
  - `app/app/components/app-header/app-header.vue`：SSO 跳转同时带 `access_token` 与 `refresh_token`。
- admin 端：
  - `admin/src/utils/auth.ts`：access/refresh 两个 key，`setTokens` / `getRefreshToken` / `removeTokens`。
  - `admin/src/stores/user.ts`：登录写入两个 token；登出清两个。
  - `admin/src/types/index.ts`：`LoginResult` 改为 `access_token` + `refresh_token`。
  - `admin/src/views/sso/index.vue`：从 hash 读取两个 token。
  - `admin/src/utils/request.ts`：401 → 用 refresh token 换新（并发请求共享同一个 refresh Promise）→ 重放原请求；失败才清 token 跳登录。
- `docker-compose.yml`：`JWT_ACCESS_EXPIRE_HOURS: 2`、`JWT_REFRESH_EXPIRE_DAYS: 7`。
- 新增 `api/spec/requests/api/v1/token_refresh_spec.rb`：refresh 成功、refresh token 不能访问受保护接口、禁用用户 refresh 返回 401/403。

### 6. Docker：健康检查与资源限制
- 新增 `api/app/controllers/health_controller.rb`：`GET /health`，执行 `SELECT 1`，成功 `{status:"ok"}`，失败 503。路由 `get "health", to: "health#show"`（不走 `/api/v1`，无需鉴权）。
- `docker-compose.yml` api 增加：
  - `healthcheck: test: ["CMD", "curl", "-fsS", "http://localhost:3000/health"]`，`interval: 15s`、`timeout: 5s`、`retries: 5`、`start_period: 30s`
- `docker-compose.yml` db 增加 `deploy.resources.limits`（`memory: 512M`、`cpus: "1.0"`）与 `reservations.memory: 256M`。
- 不改 Dockerfile 的安装步骤（curl 已存在）。

## 验证步骤
1. `docker exec rbac-api sh -c "bundle install"` 安装新 gem。
2. `docker exec rbac-api sh -c "RAILS_ENV=test bundle exec rspec"`：预期原 41 个 + 新增 model/refresh/swagger 用例全绿。
3. `docker exec rbac-api sh -c "bundle exec rake rswag:specs:swaggerize"`，然后 `curl -I http://localhost:3000/api-docs`（或 Ui 页面）确认可访问。
4. `docker compose up -d --force-recreate api db`，`docker inspect --format '{{.State.Health.Status}}' rbac-api` 为 `healthy`。
5. `curl -s -X POST http://localhost:3000/api/v1/auth/login -H 'Content-Type: application/json' -d '{"email":"admin@example.com","password":"Admin@123456"}'` 返回 `access_token` + `refresh_token`；再用 refresh_token 调 `/auth/refresh` 成功。
6. app / admin 冒烟：登录、刷新页面仍保持登录、401 后自动续期。
7. 提交并 `git push origin feat/content-community`。

## 不做 / 说明
- 不引入 Redis 黑名单做 refresh token 吊销（当前无 Redis 持久化保证），登出仍由前端清 token；如后续需要强制下线再加。
- 列表页 `/explore` 不加 SSR 缓存（含个人 liked 状态）。
- 不重构与上述 6 项无关的代码。
