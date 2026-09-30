# 权限管理平台（RBAC）

一个仓库包含三个并列模块：

| 模块       | 说明               | 技术栈                                    |
| ---------- | ------------------ | ----------------------------------------- |
| `api/`   | 后端接口服务       | Ruby on Rails 7.1（API 模式）+ PostgreSQL |
| `admin/` | 管理后台           | Vue 3 + Element Plus + Vite               |
| `app/`   | 面向用户的内容社区 | Nuxt 3                                    |

权限模型是标准的 **用户 → 角色 → 权限** 三级 RBAC，权限同时覆盖 **菜单级**（前端动态路由与侧边栏）和 **按钮级 / 接口级**（后端接口校验）。

---

## 一、技术栈

| 模块  | 技术                                                                                          |
| ----- | --------------------------------------------------------------------------------------------- |
| api   | Ruby 3.3 / Rails 7.1（`--api`）/ PostgreSQL 14+ / JWT（`jwt` gem）/ `bcrypt` / Kaminari |
| admin | Vue 3.5 / Vite 5 / TypeScript / Pinia / Vue Router 4 / Element Plus 2.8 / Axios               |
| app   | Nuxt 3 / Vue 3 / TypeScript                                                                   |
| 运行  | Docker Compose（`postgres:16-alpine` + `ruby:3.3.5-slim` + `node:20-alpine`）           |

---

## 二、目录结构

```
.
├── api/                         # Rails API 服务
│   ├── app/
│   │   ├── controllers/api/v1/  # 接口层（含面向 app 的公开接口 notes）
│   │   ├── models/              # 领域模型
│   │   ├── serializers/         # 响应序列化（纯 Ruby，无额外依赖）
│   │   ├── services/            # JsonWebToken 等
│   │   └── errors/              # AuthError / ForbiddenError
│   ├── config/                  # Rails 配置、路由、CORS
│   ├── db/migrate/              # 建表迁移
│   ├── db/seeds.rb              # 初始化权限树 / 角色 / 账号 / 社区内容
│   ├── spec/                    # RSpec 请求与模型测试
│   ├── Dockerfile               # ruby:3.3.5-slim 镜像
│   └── docker/entrypoint.sh     # 等待 DB → 迁移 → seed → 启动
│
├── admin/                       # 管理后台（Vue 3 SPA）
│   ├── src/
│   │   ├── api/                 # 接口封装
│   │   ├── router/              # 静态路由 + 动态路由生成 + 守卫
│   │   ├── stores/              # Pinia：user（身份/权限码）、permission（菜单/路由）
│   │   ├── directives/          # v-perm 按钮级权限指令
│   │   ├── layout/              # 布局、侧边栏、顶栏
│   │   └── views/               # 页面
│   ├── vite.config.ts           # 开发代理 /api -> localhost:3000
│   └── Dockerfile               # node:20-alpine 镜像
│
├── app/                         # 内容社区（Nuxt 3）
│   ├── app.vue                  # 根组件：顶栏 + 页面出口
│   ├── pages/index.vue          # 首页：频道栏 + 瀑布流
│   ├── components/
│   │   ├── AppHeader.vue        # 品牌、搜索框、发布入口
│   │   └── NoteCard.vue         # 瀑布流卡片
│   ├── composables/
│   │   ├── useNotes.ts          # 内容列表的数据获取（useAsyncData）
│   │   ├── useApi.ts            # 接口基地址（SSR 与浏览器分流）
│   │   └── useFeed.ts           # 搜索词 / 频道筛选状态 + 输入防抖
│   ├── utils/format.ts          # 点赞数格式化
│   ├── assets/css/main.css      # 全局样式（含瀑布流布局）
│   ├── nuxt.config.ts           # runtimeConfig 中配置 api 地址
│   └── Dockerfile               # node:20-alpine 镜像
│
├── docker-compose.yml           # db / api / admin / app 四服务编排
├── .env.example                 # Docker 与本地启动共用的环境变量模板
└── README.md
```

---

## 三、数据模型

| 表                   | 说明                                                                                                                                                              |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `users`            | 账号：email（唯一）、name、password_digest、status（0 禁用 / 1 启用）、last_login_at                                                                              |
| `roles`            | 角色：name、code（唯一，如`user_manager`）、status、`built_in`（内置角色不可删）                                                                              |
| `permissions`      | 权限节点：name、code（唯一，如`system:user:create`）、`type`（0 菜单 / 1 按钮）、parent_id（自关联树）、path / component / icon（菜单路由信息）、sort、status |
| `user_roles`       | 用户-角色关联（联合唯一）                                                                                                                                         |
| `role_permissions` | 角色-权限关联（联合唯一）                                                                                                                                         |
| `notes`            | 社区内容：title、cover_url、cover_ratio（封面宽高比，图片加载前占位用）、author_name、avatar_color、likes_count、channel、sort                                    |

### 权限码约定

采用 `模块:资源:操作` 三段式，与 `admin/src/views/` 目录一一对应：

```
system            菜单「系统管理」（目录节点，无 component）
system:user       菜单「用户管理」      -> views/system/user/index.vue
system:user:list  按钮「查询用户」
system:user:create / system:user:update / system:user:delete
```

- **菜单**（`type = 0`）会出现在侧边栏，并参与前端动态路由生成。
- **按钮**（`type = 1`）不生成路由，用于 `v-perm` 指令与后端 `authorize!` 校验。
- 角色若勾选了某个子菜单，前端提交时会一并提交其 **半选中的父级菜单**，否则父菜单不会出现在侧边栏（`admin/src/views/system/role/index.vue` 中已处理）。

### 超级管理员

`roles.code = 'super_admin'` 且 `built_in = true` 的角色为超级管理员，其成员会 **跳过全部权限校验**（`User#super_admin?`），并且该角色不可删除、不可改编码。

超管账号本身同样受保护：非超管即使持有 `system:user:update` / `system:user:delete`，也只能在列表中看到超管账号，不能编辑、禁用、重置密码或删除它（后端 `ensure_target_manageable!` 拦截，前端对应按钮置灰并提示「超级管理员账号仅超级管理员可操作」）。此外非超管不能把 `super_admin` 角色分配给任何人——`role_ids` 会被校验拒绝，`/roles/options` 也不会返回该角色，避免越权提权。

---

## 四、Docker 一键运行（推荐）

前置只有一条：本机已安装并 **启动** Docker Desktop（`docker info` 能正常返回即可），无需在宿主机安装 Ruby / Node / PostgreSQL。

### 1. 启动

```bash
cd rbac
docker compose up -d --build
```

首次启动会自动完成：构建 api / admin / app 镜像 → 启动 PostgreSQL → 等数据库健康检查通过 → 执行 `db:prepare` 建库建表 → 执行 `db:seed` 灌入初始权限树、账号与社区内容 → 启动 Rails、Vite 与 Nuxt。

跟踪启动进度：

```bash
docker compose logs -f
```

看到 `api` 输出 `权限初始化完成：17 个权限节点 / 3 个角色 / 2 个账号` 与 `内容初始化完成：18 条内容 / 9 个频道` 即为就绪（`db:seed` 是幂等的，重复启动不会产生重复数据）。

### 2. 访问地址

| 地址                  | 模块  | 说明                            |
| --------------------- | ----- | ------------------------------- |
| http://localhost:5173 | admin | 管理后台（Vite Dev Server）     |
| http://localhost:3001 | app   | 内容社区首页（Nuxt Dev Server） |
| http://localhost:3000 | api   | 后端 API                        |
| localhost:5432        | db    | PostgreSQL                      |

### 3. 常用命令

```bash
docker compose ps                                     # 查看四个容器状态
docker compose logs -f api                            # 跟踪后端日志
docker compose logs -f app                            # 跟踪 app 日志
docker compose exec api bash                          # 进入后端容器
docker compose exec api ruby bin/rails console        # Rails 控制台
docker compose exec api ruby bin/rails db:seed        # 重新灌入种子数据（含社区内容）
docker compose exec db psql -U postgres -d rbac_admin_development   # 直连数据库
docker compose restart api                            # 重启某个服务
docker compose down                                   # 停止并删除容器（数据库数据保留）
docker compose down -v                                # 停止并删除容器 + 数据卷（数据清空）
```

### 4. 环境变量

`.env.example` 复制为 `.env` 后可覆盖默认值，`docker compose` 会自动读取：

```ini
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=rbac_admin_development
DB_PORT_PUBLISHED=5432            # 宿主机映射端口，本机 5432 被占用时改这一项
JWT_SECRET=dev-only-secret-please-change-in-production-32chars
```

各模块单独需要的变量写在 `docker-compose.yml` 里：admin 用 `VITE_PROXY_TARGET` 指向 `api:3000`，app 用 `NUXT_API_SERVER_BASE` / `NUXT_PUBLIC_API_BASE` 区分服务端与浏览器要访问的 api 地址。

### 5. 实现要点

- `./api`、`./admin`、`./app` 以 **绑定挂载** 方式进入容器，改代码即时生效（Rails 开发模式自动 reload + Vite / Nuxt HMR）。
- 两个 Node 模块的 `node_modules` 各自放在命名卷（`admin_node_modules` / `app_node_modules`）中，避免宿主机与容器的依赖互相污染；后端 `bundle` 路径同理。
- 两个 Node 镜像都设置 `CHOKIDAR_USEPOLLING=true`，并在 Vite / Nuxt 配置里开启 `watch.usePolling`，解决 Windows 挂载目录下文件变更事件不触发的问题。
- Windows 挂载进容器的文件 **没有可执行位**，所以 `entrypoint.sh` 中统一用 `ruby bin/rails ...` 而非 `bin/rails ...`。
- `api/tmp/pids/server.pid` 位于绑定挂载目录中，容器被强制重启（崩溃、`docker kill`）时该文件会残留在宿主机；而容器内 Puma 的 PID 恒为 `1`，残留文件会让 Puma 误判「已有实例在运行」而拒绝启动，进而形成 `exited with code 1 (restarting)` 循环。因此 `entrypoint.sh` 在启动前会执行 `rm -f tmp/pids/server.pid`。
- `api/Gemfile` 将 `json` 锁定在 `~> 2.7`：`json 3.x` 移除了 `quirks_mode` 关键字，与 Rails 7.1 的 JSON 编码不兼容，会导致所有 JSON 响应 500。
- 若拉取官方镜像缓慢，可在 Docker Desktop 的 `settings.json` 中配置 `registry-mirrors`，或先 `docker pull` 加速镜像后再 `docker tag` 为 `ruby:3.3.5-slim` / `node:20-alpine` / `postgres:16-alpine` 通用标签。

---

## 五、本地启动步骤（不使用 Docker）

### 1. 后端 api

前置：Ruby 3.3+、PostgreSQL 已启动。

```bash
cd api

# 安装依赖
bundle install

# 配置环境变量（可选，不配置则使用 database.yml 中的默认值）
cp .env.example .env

# 建库、建表、灌入初始权限与账号
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# 启动（默认 http://localhost:3000）
bin/rails server
```

`.env` 关键项：

```ini
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
JWT_SECRET=please-change-me-to-a-long-random-string   # 生产环境必须替换
JWT_EXPIRE_HOURS=12
CORS_ORIGINS=http://localhost:5173,http://localhost:3001   # admin 与 app 都要放行
```

### 2. 管理后台 admin

前置：Node.js 18+。

```bash
cd admin

npm install
npm run dev        # http://localhost:5173
```

开发环境已在 `vite.config.ts` 中将 `/api` 代理到 `http://localhost:3000`，因此无需处理跨域。
生产构建：`npm run build`（产物在 `admin/dist`）。

### 3. 内容社区 app

前置：Node.js 18+。

```bash
cd app

npm install
npm run dev        # http://localhost:3000，容器里映射到宿主机的 3001
```

app 是直接（非代理）访问 api 的，默认地址 `http://localhost:3000/api/v1`，可用环境变量覆盖：

```bash
NUXT_API_SERVER_BASE=http://localhost:3000/api/v1 \
NUXT_PUBLIC_API_BASE=http://localhost:3000/api/v1 \
npm run dev
```

生产构建：`npm run build`，产物在 `app/.output`。

### 4. 默认账号

| 账号                    | 密码               | 角色       | 权限范围                       |
| ----------------------- | ------------------ | ---------- | ------------------------------ |
| `admin@example.com`   | `Admin@123456`   | 超级管理员 | 全部权限，跳过校验             |
| `manager@example.com` | `Manager@123456` | 用户管理员 | 仅用户管理的查询 / 新增 / 编辑 |

> 用 `manager` 登录可以直观看到菜单裁剪、按钮隐藏和接口 403 的效果。

---

## 六、接口一览

所有接口前缀 `/api/v1`。**除内容接口外**，均需携带请求头 `Authorization: Bearer <token>`。

### 内容（app 模块，公开）

| 方法 | 路径       | 说明                                                                                | 所需权限 |
| ---- | ---------- | ----------------------------------------------------------------------------------- | -------- |
| GET  | `/notes` | 内容列表，按`sort` 升序；支持 `channel` / `keyword` / `page` / `per_page` | 公开     |

响应同时带上频道列表，前端一次请求就能渲染频道栏：

```json
{
  "items": [
    {
      "id": 1,
      "title": "夏日清爽穿搭｜白衬衫 + 直筒牛仔，通勤也能很松弛",
      "cover": "https://.../text_to_image?prompt=...&image_size=portrait_4_3",
      "cover_ratio": 0.75,
      "author": "穿搭日记",
      "avatar_color": "#ff6b6b",
      "likes": 12000,
      "channel": "穿搭"
    }
  ],
  "channels": ["推荐", "穿搭", "美食", "..."],
  "meta": { "page": 1, "per_page": 10, "total": 18, "total_pages": 2 }
}
```

- `channels` 的第一项 `推荐` 是 **虚拟频道**，等价于不做频道过滤（`channel=推荐` 或留空都返回全部）。
- `keyword` 会同时匹配标题、作者和频道名。
- `cover_ratio` 是封面宽高比，前端在图片加载前用它占位，避免瀑布流抖动。

### 认证

| 方法   | 路径             | 说明                             | 所需权限 |
| ------ | ---------------- | -------------------------------- | -------- |
| POST   | `/auth/login`  | 登录，返回 token + 用户 + 权限码 | 公开     |
| DELETE | `/auth/logout` | 登出（前端清除 token）           | 登录即可 |
| GET    | `/auth/me`     | 当前用户信息 + 权限码            | 登录即可 |
| GET    | `/menus`       | 当前用户可见的菜单树             | 登录即可 |

### 用户

| 方法   | 路径                    | 说明                                                 | 所需权限               |
| ------ | ----------------------- | ---------------------------------------------------- | ---------------------- |
| GET    | `/users`              | 分页列表，支持`keyword` / `status` / `role_id` | `system:user:list`   |
| GET    | `/users/:id`          | 详情                                                 | `system:user:list`   |
| POST   | `/users`              | 新增                                                 | `system:user:create` |
| PATCH  | `/users/:id`          | 编辑（含角色分配`role_ids`）                       | `system:user:update` |
| PATCH  | `/users/:id/status`   | 启用 / 禁用                                          | `system:user:update` |
| PATCH  | `/users/:id/password` | 管理员重置密码                                       | `system:user:update` |
| DELETE | `/users/:id`          | 删除                                                 | `system:user:delete` |

### 角色

| 方法   | 路径               | 说明                             | 所需权限                                     |
| ------ | ------------------ | -------------------------------- | -------------------------------------------- |
| GET    | `/roles`         | 分页列表                         | `system:role:list`                         |
| GET    | `/roles/options` | 下拉选项（非超管不返回超管角色） | `system:role:list` 或 `system:user:list` |
| GET    | `/roles/:id`     | 详情（含`permission_ids`）     | `system:role:list`                         |
| POST   | `/roles`         | 新增（含`permission_ids`）     | `system:role:create`                       |
| PATCH  | `/roles/:id`     | 编辑（含`permission_ids`）     | `system:role:update`                       |
| DELETE | `/roles/:id`     | 删除                             | `system:role:delete`                       |

### 权限

| 方法   | 路径                     | 说明                                                    | 所需权限                                           |
| ------ | ------------------------ | ------------------------------------------------------- | -------------------------------------------------- |
| GET    | `/permissions`         | 树形列表；`flat=true` 或带 `keyword` 时返回平铺列表 | `system:permission:list`                         |
| GET    | `/permissions/options` | 上级菜单下拉数据                                        | `system:permission:list` 或 `system:role:list` |
| POST   | `/permissions`         | 新增                                                    | `system:permission:create`                       |
| PATCH  | `/permissions/:id`     | 编辑                                                    | `system:permission:update`                       |
| DELETE | `/permissions/:id`     | 删除（有子节点或已被角色引用时拒绝）                    | `system:permission:delete`                       |

### 个人中心

| 方法  | 路径                  | 说明                         |
| ----- | --------------------- | ---------------------------- |
| GET   | `/profile`          | 当前用户资料 + 角色 + 权限码 |
| PATCH | `/profile`          | 修改昵称 / 邮箱              |
| PATCH | `/profile/password` | 修改密码（需校验当前密码）   |

### 响应约定

- 成功：直接返回业务数据；列表统一为 `{ items: [...], meta: { page, per_page, total, total_pages } }`
- 失败：HTTP 状态码 + `{ "error": "错误描述" }`，字段级校验失败时附带 `details`
- `401` 未登录 / token 失效，前端拦截器会自动清理 token 并跳转登录页
- `403` 已登录但缺少权限，错误信息中会列出所需权限码
- `422` 参数校验失败

---

## 七、管理后台的权限机制

1. **登录**：`stores/user.ts` 保存 token，并记录后端返回的 `permissions`（权限码数组）与 `roles`。
2. **动态路由**：路由守卫 `router/guard.ts` 在首次进入时调用 `/menus` 拿到菜单树，由 `router/dynamic.ts` 转换为路由记录后 `router.addRoute` 注册，兜底 404 路由在动态路由之后注册。
3. **侧边栏**：`layout/components/SidebarItem.vue` 递归渲染菜单树，`icon` 字段直接对应全局注册的 Element Plus 图标名。
4. **按钮级权限**：

   ```vue
   <el-button v-perm="'system:user:create'">新增</el-button>
   <el-button v-perm="['system:user:update', 'system:user:delete']">批量操作</el-button>
   ```

   不满足权限时元素会从 DOM 中移除。
5. **接口级权限**：后端 `Api::V1::BaseController#authorize!(*codes)` 按权限码校验，前端的按钮隐藏只是体验优化，真正的安全边界在后端。

---

## 八、内容社区 app

`app/` 是一个独立的 Nuxt 3 应用，入口 `/` 直接就是内容首页，与管理后台互不影响。

### 首页形态

- **顶栏**：品牌标、搜索框、发布入口，`position: sticky` 吸顶。
- **频道栏**：`推荐 / 穿搭 / 美食 / 彩妆 / 旅行 / 家居 / 健身 / 读书 / 萌宠 / 好物`，数据来自接口返回的 `channels`。
- **瀑布流**：CSS 多列（`column-count` + `break-inside: avoid`）实现，卡片高度随封面比例自然错落；按 1500 / 1100 / 760 三档断点切换 5 / 4 / 3 / 2 列。
- **卡片**：封面、两行标题、作者头像（取昵称首字 + `avatar_color`）、点赞数（超过 1 万折算成 `1.2万`），点击红心可切换点赞态。

### 数据来源

内容全部来自 api 的公开接口 `GET /api/v1/notes`，18 条种子数据在 `api/db/seeds.rb` 末尾的「内容社区」段落维护，改完执行：

```bash
docker compose exec api ruby bin/rails db:seed
```

请求分两条路径，由 `app/composables/useApi.ts` 按环境选择：

| 场景                | 地址                             | 说明                                             |
| ------------------- | -------------------------------- | ------------------------------------------------ |
| SSR 首次直出        | `http://api:3000/api/v1`       | 容器内网直连 api 服务，不经过浏览器              |
| 浏览器切频道 / 搜索 | `http://localhost:3000/api/v1` | 直连 api，跨域由后端的`CORS_ORIGINS` 放行 3001 |

两个地址来自 `nuxt.config.ts` 的 `runtimeConfig.apiServerBase` / `runtimeConfig.public.apiBase`，可分别用 `NUXT_API_SERVER_BASE` / `NUXT_PUBLIC_API_BASE` 覆盖（`docker-compose.yml` 里已设好）。

### 筛选与搜索

频道和关键词都交给后端过滤，前端只负责传参：

- 切频道 → 请求带 `channel`，`推荐` 由后端识别为「不过滤」
- 输入搜索词 → 防抖 300ms 后才发请求，避免每敲一个字打一次接口
- 请求中瀑布流会轻微变淡；无结果展示空状态；接口不可用时提示「内容加载失败」

> 点赞目前只有前端状态（数量 +1、红心点亮），还没有对应的写接口，刷新后会还原。

---

## 九、扩展一个新模块

以「订单管理」为例（管理后台侧）：

1. 在「权限管理」页面新增权限节点：

   | 名称     | 编码                  | 类型 | 路由地址        | 组件路径             | 上级     |
   | -------- | --------------------- | ---- | --------------- | -------------------- | -------- |
   | 订单管理 | `order`             | 菜单 | `/order`      | （留空，目录节点）   | 无       |
   | 订单列表 | `order:list`        | 菜单 | `/order/list` | `order/list/index` | 订单管理 |
   | 查询订单 | `order:list:view`   | 按钮 | -               | -                    | 订单列表 |
   | 取消订单 | `order:list:cancel` | 按钮 | -               | -                    | 订单列表 |


   > 组件路径是相对 `admin/src/views/` 的路径（不含 `.vue`）。
   >
2. 在 `admin/src/views/order/list/index.vue` 创建页面组件（无需改动路由文件）。
3. 在「角色管理」中把新权限勾选给对应角色，重新登录即可看到菜单。

后端新增业务接口时，在控制器中调用 `authorize!("order:list:cancel")` 即可完成接口级鉴权。

---

## 十、测试

```bash
cd api
bin/rails db:test:prepare
bundle exec rspec
```

Docker 环境下执行（注意 `RAILS_ENV` 要用 `docker compose exec -e` 传，写在 `sh -c "..."` 里的 `VAR=x cmd1 && cmd2` 只对第一条命令生效）：

```bash
docker compose exec -e RAILS_ENV=test api bundle exec rspec
```

已包含：登录成功 / 密码错误 / 账号禁用、无 token 访问、权限码校验通过 / 403、超级管理员旁路、超管账号保护与越权提权拦截，以及内容接口的公开访问、字段契约、频道过滤、关键词搜索与排序等用例。
