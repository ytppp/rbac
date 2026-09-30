# 路由表 —— 整个后端的「请求地址 -> 控制器方法」对照清单。
#
# 一个请求进来时，Rails 会在这里从上往下匹配，找到第一条符合的就交给对应控制器。
# 这里所有路由都包在 namespace :api 和 namespace :v1 里，
# 所以实际访问地址都会带 /api/v1 前缀（namespace 既加前缀，也决定去哪个目录找控制器）。
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # 认证
      # 写法是 "方法 路径", to: "控制器#action"
      # get/post/delete 对应 HTTP 方法；第一个参数是地址，第二个参数指定要调用哪个方法
      post   "auth/login",  to: "auth#login"
      delete "auth/logout", to: "auth#logout"
      get    "auth/me",     to: "auth#me"

      # 当前用户可访问的菜单树（前端动态路由的数据源）
      get "menus", to: "menus#index"

      # 内容社区（app 模块）的公开只读接口，无需登录
      # resources 是 Rails 的「批量生成标准路由」写法。
      #   resources :notes, only: %i[index] 等价于：
      #     get "/notes", to: "notes#index"
      # 加上 only 就只生成列表这一条，不会生成增删改。
      resources :notes, only: %i[index]

      # 个人中心。
      # 注意 resource 是「单数」——表示「当前用户唯一的那一份资料」，地址里不带 id：
      #   GET   /api/v1/profile
      #   PATCH /api/v1/profile
      # `do ... end` 块里可以追加自定义子路由（这里是改密码）。
      # controller: "profiles" 是因为单数 resource 会默认去找 ProfileController，
      # 而我们的控制器叫 ProfilesController，所以要显式指定。
      resource :profile, only: %i[show update], controller: "profiles" do
        # 块内路径会拼在父路由后面，最终地址是 PATCH /api/v1/profile/password
        patch :password
      end

      # 用户管理。resources（复数）会生成一批标准 RESTful 路由：
      #   GET    /users          index
      #   GET    /users/:id      show
      #   POST   /users          create
      #   PATCH  /users/:id      update
      #   DELETE /users/:id      destroy
      resources :users, only: %i[index show create update destroy] do
        # member 块：路由里带 :id，作用于「某个具体用户」
        member do
          # patch /users/:id/status -> 调用 UsersController#status
          patch :status
          # action: :reset_password 表示地址用 password，但实际调用的方法名是 reset_password
          patch :password, action: :reset_password
        end
      end

      resources :roles, only: %i[index show create update destroy] do
        # collection 块：路由里不带 :id，作用于「角色这个集合」
        # 所以完整地址是 GET /api/v1/roles/options，用来给下拉框取数据
        collection do
          get :options
        end
      end

      resources :permissions, only: %i[index show create update destroy] do
        collection do
          get :options
        end
      end
    end
  end
end
