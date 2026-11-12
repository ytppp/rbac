# 路由表：请求地址 -> 控制器方法的映射，全部挂在 /api/v1 前缀下。
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post   "auth/login",  to: "auth#login"
      post   "auth/register", to: "auth#register"
      delete "auth/logout", to: "auth#logout"
      get    "auth/me",     to: "auth#me"

      get "menus", to: "menus#index"

      # 内容社区（app 模块）公开只读接口，无需登录
      resources :notes, only: %i[index show] do
        member do
          post   :like
          delete :unlike
          post   :favorite
          delete :unfavorite
        end
      end

      # 内容评论：列表公开，发布 / 删除 / 点赞需要登录
      get  "notes/:note_id/comments", to: "comments#index"
      post "notes/:note_id/comments", to: "comments#create"
      resources :comments, only: %i[destroy] do
        member do
          post   :like
          delete :unlike
        end
      end

      # 个人中心：我发布的 / 我的收藏 / 我点赞的
      get "me/notes",     to: "me#notes"
      get "me/favorites", to: "me#favorites"
      get "me/likes",     to: "me#likes"

      # 作者主页：公开
      get "authors/:id", to: "authors#show"

      # 内容标签：公开读取
      resources :tags, only: %i[index]

      # 举报与站内通知
      post  "notes/:id/reports", to: "reports#create"
      post  "comments/:id/reports", to: "reports#create_comment"
      get   "notifications", to: "notifications#index"
      patch "notifications/read_all", to: "notifications#read_all"
      patch "notifications/:id/read", to: "notifications#read"

      # 管理后台内容管理，需要 content:note:* 权限
      namespace :admin do
        # 首页数据看板
        get "dashboard/stats", to: "dashboard#stats"
        resources :notes, only: %i[index create update destroy]
        # 标签维护：需要 content:tag:* 权限
        resources :tags, only: %i[index create update destroy]
        # 举报处理：需要 content:report:* 权限
        resources :reports, only: %i[index update]
        # 内容详情页的多图上传：POST /api/v1/admin/note_images
        resources :note_images, only: %i[create]
      end

      resource :profile, only: %i[show update], controller: "profiles" do
        patch :password
        # 头像的上传 / 删除：POST /api/v1/profile/avatar、DELETE /api/v1/profile/avatar
        resource :avatar, only: %i[create destroy], controller: "avatars"
      end

      resources :users, only: %i[index show create update destroy] do
        member do
          patch :status
          patch :password, action: :reset_password
        end
      end

      resources :roles, only: %i[index show create update destroy] do
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
