FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "用户#{n}" }
    password { "Password@123" }
    status { :enabled }

    transient do
      role_codes { [] }
    end

    after(:create) do |user, evaluator|
      evaluator.role_codes.each do |code|
        user.roles << Role.find_or_create_by!(code: code) do |role|
          role.name = code
          role.status = :enabled
        end
      end
    end
  end

  factory :role do
    sequence(:name) { |n| "角色#{n}" }
    sequence(:code) { |n| "role_#{n}" }
    status { :enabled }

    trait :super_admin do
      name { "超级管理员" }
      code { Role::SUPER_ADMIN_CODE }
      built_in { true }
    end

    transient do
      permission_codes { [] }
    end

    after(:create) do |role, evaluator|
      evaluator.permission_codes.each do |code|
        role.permissions << Permission.find_or_create_by!(code: code) do |permission|
          permission.name = code
          # 形如 system:user:list 视为按钮，形如 system:user 视为菜单
          permission.type = code.split(":").length >= 3 ? :button : :menu
          permission.path = "/#{code.tr(':', '/')}"
          permission.sort = 0
          permission.status = :enabled
        end
      end
    end
  end

  factory :permission do
    sequence(:name) { |n| "权限#{n}" }
    sequence(:code) { |n| "demo:perm_#{n}" }
    type { :button }
    sort { 0 }
    status { :enabled }
  end

  factory :note do
    sequence(:title) { |n| "内容标题#{n}" }
    cover_url { "https://example.com/cover.jpg" }
    cover_ratio { 0.75 }
    sequence(:author_name) { |n| "作者#{n}" }
    avatar_color { "#ff6b6b" }
    likes_count { 100 }
    sequence(:channel) { |n| "频道#{n}" }
    sequence(:sort) { |n| n }
  end
end
