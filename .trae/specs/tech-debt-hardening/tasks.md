# 任务清单

## A. 测试
- [x] A1 `api/spec/factories/all.rb` 增加 comment / report / notification factory
- [x] A2 新增 `api/spec/models/report_spec.rb`
- [x] A3 新增 `api/spec/models/comment_spec.rb`
- [x] A4 新增 `api/spec/models/notification_spec.rb`
- [x] A5 `api/config/environments/test.rb` 设置 ActiveJob test adapter

## B. 日志
- [x] B1 Gemfile 增加 lograge + logstash-event
- [x] B2 新增 `api/config/initializers/lograge.rb`
- [x] B3 `production.rb` 移除 log_tags
- [x] B4 compose api/sidekiq 增加 `LOGRAGE_ENABLED=true`

## C. Docker
- [x] C1 新增 `HealthController` + `GET /health` 路由
- [x] C2 compose api 增加 healthcheck
- [x] C3 compose db 增加 CPU/内存限制

## D. SSR
- [x] D1 `app/nuxt.config.ts` 增加 explore routeRules（swr 60）
- [x] D2 `[id].vue` SSR 不带 token + 客户端补拉个人状态

## E. 安全（JWT access + refresh）
- [x] E1 `JsonWebToken` 拆分 access / refresh 并校验 type
- [x] E2 `AuthController#session_payload` + `#refresh` + 限流
- [x] E3 路由增加 `auth/refresh`
- [x] E4 app `useAuth` / `useApiFetch` / `app-header` 适配
- [x] E5 admin `auth.ts` / `user.ts` / `types` / `sso` / `request.ts` 适配
- [x] E6 compose 增加 JWT 有效期环境变量
- [x] E7 新增 refresh 请求 spec

## F. API 文档（rswag）
- [x] F1 Gemfile 增加 rswag-api / rswag-ui / rswag-specs
- [x] F2 initializers + 路由 mount `/api-docs`
- [x] F3 `spec/swagger_helper.rb` + 核心接口 swagger spec
- [x] F4 生成 `swagger/v1/swagger.yaml`

## G. 验证与提交
- [x] G1 `RAILS_ENV=test bundle exec rspec` 全绿（73 examples）
- [x] G2 swaggerize + `/api-docs` 可访问
- [x] G3 compose 重建，api healthy；登录/refresh 冒烟
- [x] G4 提交并 push `feat/content-community`
