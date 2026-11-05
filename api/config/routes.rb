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
        end
      end

      # 管理后台内容管理，需要 content:note:* 权限
      namespace :admin do
        resources :notes, only: %i[index create update destroy]
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
