# 初始化数据脚本（种子数据），容器启动时由 docker/entrypoint.sh 调用。
# 使用 find_or_initialize_by + save!，幂等：重复执行不会产生重复记录。

# ---------- 权限树 ----------
PERMISSION_TREE = [
  {
    name: "仪表盘",
    code: "dashboard",
    type: :menu,
    path: "/dashboard",
    component: "dashboard/index",
    icon: "Odometer",
    sort: 1,
    children: []
  },
  {
    name: "系统管理",
    code: "system",
    type: :menu,
    path: "/system",
    component: nil,
    icon: "Setting",
    sort: 90,
    children: [
      {
        name: "用户管理",
        code: "system:user",
        type: :menu,
        path: "/system/user",
        component: "system/user/index",
        icon: "User",
        sort: 1,
        children: [
          # 按钮级权限：既控制前端显隐，也是后端 authorize! 的依据
          { name: "查询用户", code: "system:user:list", type: :button, sort: 1 },
          { name: "新增用户", code: "system:user:create", type: :button, sort: 2 },
          { name: "编辑用户", code: "system:user:update", type: :button, sort: 3 },
          { name: "删除用户", code: "system:user:delete", type: :button, sort: 4 }
        ]
      },
      {
        name: "角色管理",
        code: "system:role",
        type: :menu,
        path: "/system/role",
        component: "system/role/index",
        icon: "UserFilled",
        sort: 2,
        children: [
          { name: "查询角色", code: "system:role:list", type: :button, sort: 1 },
          { name: "新增角色", code: "system:role:create", type: :button, sort: 2 },
          { name: "编辑角色", code: "system:role:update", type: :button, sort: 3 },
          { name: "删除角色", code: "system:role:delete", type: :button, sort: 4 }
        ]
      },
      {
        name: "权限管理",
        code: "system:permission",
        type: :menu,
        path: "/system/permission",
        component: "system/permission/index",
        icon: "Menu",
        sort: 3,
        children: [
          { name: "查询权限", code: "system:permission:list", type: :button, sort: 1 },
          { name: "新增权限", code: "system:permission:create", type: :button, sort: 2 },
          { name: "编辑权限", code: "system:permission:update", type: :button, sort: 3 },
          { name: "删除权限", code: "system:permission:delete", type: :button, sort: 4 }
        ]
      }
    ]
  },
  {
    # 内容管理：管理 app 首页瀑布流卡片（notes 表）
    name: "内容管理",
    code: "content",
    type: :menu,
    path: "/content",
    component: nil,
    icon: "Picture",
    sort: 80,
    children: [
      {
        name: "内容列表",
        code: "content:note",
        type: :menu,
        path: "/content/note",
        component: "content/note/index",
        icon: "Document",
        sort: 1,
        children: [
          { name: "查询内容", code: "content:note:list", type: :button, sort: 1 },
          { name: "新增内容", code: "content:note:create", type: :button, sort: 2 },
          { name: "编辑内容", code: "content:note:update", type: :button, sort: 3 },
          { name: "删除内容", code: "content:note:delete", type: :button, sort: 4 }
        ]
      }
    ]
  }
].freeze

def seed_permissions(nodes, parent = nil)
  nodes.each do |node|
    permission = Permission.find_or_initialize_by(code: node[:code])
    permission.assign_attributes(
      name: node[:name],
      type: node[:type] || :menu,
      parent: parent,
      path: node[:path],
      component: node[:component],
      icon: node[:icon],
      sort: node[:sort] || 0,
      status: :enabled
    )
    permission.save!
    seed_permissions(node[:children] || [], permission)
  end
end

seed_permissions(PERMISSION_TREE)

all_permission_ids = Permission.pluck(:id)

# ---------- 角色 ----------
# 超管会跳过权限校验，但仍全量授权，保证角色页的权限清单完整
super_admin = Role.find_or_initialize_by(code: Role::SUPER_ADMIN_CODE)
super_admin.assign_attributes(
  name: "超级管理员",
  description: "拥有全部权限，且不受权限校验限制（内置角色）",
  status: :enabled,
  built_in: true
)
super_admin.save!
super_admin.permission_ids = all_permission_ids

# 故意不给 user:delete，用于演示不同角色的按钮差异
user_manager_codes = %w[
  dashboard
  system
  system:user system:user:list system:user:create system:user:update
]
user_manager = Role.find_or_initialize_by(code: "user_manager")
user_manager.assign_attributes(
  name: "用户管理员",
  description: "仅可查看、新增、编辑用户，无法删除用户与调整角色权限",
  status: :enabled,
  built_in: false
)
user_manager.save!
user_manager.permission_ids = Permission.where(code: user_manager_codes).pluck(:id)

# 只读访客：只能看列表
viewer = Role.find_or_initialize_by(code: "viewer")
viewer.assign_attributes(
  name: "只读访客",
  description: "仅可查看仪表盘与系统管理下的列表数据",
  status: :enabled,
  built_in: false
)
viewer.save!
viewer.permission_ids = Permission.where(
  code: %w[dashboard system system:user system:user:list system:role system:role:list]
).pluck(:id)

# ---------- 账号 ----------
admin = User.find_or_initialize_by(email: "admin@example.com")
admin.assign_attributes(name: "超级管理员", status: :enabled)
# 仅在新建时设密码：密码哈希不可逆，重设会覆盖用户已改过的密码
admin.password = "Admin@123456" if admin.new_record?
admin.save!
admin.role_ids = [super_admin.id] if admin.user_roles.empty?

manager = User.find_or_initialize_by(email: "manager@example.com")
manager.assign_attributes(name: "用户管理员", status: :enabled)
manager.password = "Manager@123456" if manager.new_record?
manager.save!
manager.role_ids = [user_manager.id] if manager.user_roles.empty?

puts "权限初始化完成：#{Permission.count} 个权限节点 / #{Role.count} 个角色 / #{User.count} 个账号"
puts "默认账号：admin@example.com / Admin@123456"
puts "默认账号：manager@example.com / Manager@123456"

# ---------- 内容社区（app 模块）----------
# 封面由文生图服务按提示词生成，可用 IMAGE_API_BASE 覆盖
note_image_api = ENV.fetch("IMAGE_API_BASE", "https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image")

# 各尺寸对应的宽高比；整数相除结果为 0，必须写成浮点
note_cover_ratios = {
  "square_hd" => 1.0,
  "square" => 1.0,
  "portrait_4_3" => 3.0 / 4,
  "portrait_16_9" => 9.0 / 16,
  "landscape_4_3" => 4.0 / 3,
  "landscape_16_9" => 16.0 / 9
}.freeze

# 头像底色，按下标循环取用
note_avatar_colors = %w[#ff6b6b #f7a072 #f2b705 #06d6a0 #4cc9f0 #7b6cf6 #ef7bb0 #8ac926].freeze

note_seeds = [
  {
    title: "夏日清爽穿搭｜白衬衫 + 直筒牛仔，通勤也能很松弛",
    prompt: "young woman wearing white linen shirt and light blue straight jeans, urban street, natural daylight, minimalist aesthetic, full body shot",
    size: "portrait_4_3",
    author: "穿搭日记",
    likes: 12000,
    channel: "穿搭"
  },
  {
    title: "一人食的仪式感：番茄意面配牛油果沙拉",
    prompt: "home made tomato pasta with avocado salad on ceramic plate, warm lamp light, top down flat lay food photography",
    size: "square_hd",
    author: "食光记",
    likes: 8632,
    channel: "美食"
  },
  {
    title: "通勤妆 10 分钟搞定｜三步出门不慌张",
    prompt: "makeup brushes and eyeshadow palette on marble vanity, soft morning light, clean beauty flat lay",
    size: "portrait_16_9",
    author: "momo",
    likes: 4521,
    channel: "彩妆"
  },
  {
    title: "周末去露营｜天幕一搭，夏天就慢下来了",
    prompt: "camping tent and tarp on green meadow at golden hour, mountains in background, cozy outdoor lifestyle",
    size: "landscape_4_3",
    author: "山野拾光",
    likes: 23140,
    channel: "旅行"
  },
  {
    title: "出租屋改造｜2000 块把客厅换了个气质",
    prompt: "small apartment living room with oak bookshelf and green plants, warm indoor lighting, scandinavian style",
    size: "portrait_4_3",
    author: "木木子",
    likes: 9807,
    channel: "家居"
  },
  {
    title: "健身打卡 Day 30｜坚持一个月真实变化",
    prompt: "dumbbells and yoga mat in a bright modern gym, cool tone, fitness lifestyle photography",
    size: "square_hd",
    author: "健身教练Leo",
    likes: 6754,
    channel: "健身"
  },
  {
    title: "秋日复古穿搭｜卡其风衣配马丁靴真的显高",
    prompt: "autumn retro outfit, khaki trench coat and dark boots, falling leaves on city street, film photography",
    size: "portrait_16_9",
    author: "半夏",
    likes: 15420,
    channel: "穿搭"
  },
  {
    title: "自制生椰拿铁｜比外面买的还香",
    prompt: "iced coconut latte in tall glass with layered milk and coffee, wooden table, soft daylight",
    size: "portrait_4_3",
    author: "咖啡因依赖",
    likes: 7390,
    channel: "美食"
  },
  {
    title: "打工人的 5 分钟早餐｜三明治 + 热美式",
    prompt: "breakfast sandwich and hot americano on window side table, early morning light, cozy minimal",
    size: "landscape_4_3",
    author: "一只柚子",
    likes: 3120,
    channel: "美食"
  },
  {
    title: "海边小城散步｜慢下来的三天",
    prompt: "white washed houses and blue sea in a small mediterranean coastal town, bright sunny day, travel photography",
    size: "portrait_4_3",
    author: "旅行的意义",
    likes: 19870,
    channel: "旅行"
  },
  {
    title: "护肤空瓶记｜这几瓶是真的会回购",
    prompt: "minimal skincare bottles arranged on white surface, soft shadow, clean product photography",
    size: "square_hd",
    author: "元气少女",
    likes: 5643,
    channel: "彩妆"
  },
  {
    title: "治愈系书单｜适合睡前读的 5 本",
    prompt: "open book and a cup of tea on a wooden desk, cozy afternoon light, reading corner",
    size: "portrait_16_9",
    author: "猫与旧书",
    likes: 8210,
    channel: "读书"
  },
  {
    title: "山间民宿｜推窗就是云海，值了",
    prompt: "mountain guesthouse with floor to ceiling window overlooking sea of clouds and forest, early morning",
    size: "landscape_4_3",
    author: "城市漫游者",
    likes: 26730,
    channel: "旅行"
  },
  {
    title: "猫咪的午后｜阳光是最好的滤镜",
    prompt: "orange tabby cat napping on a rug in warm afternoon sunlight, cozy home interior",
    size: "square_hd",
    author: "甜甜圈",
    likes: 34120,
    channel: "萌宠"
  },
  {
    title: "平价好物｜帆布包和墨镜，出门百搭",
    prompt: "canvas tote bag and sunglasses flat lay on beige background, minimalist product styling",
    size: "portrait_4_3",
    author: "极简主义",
    likes: 4108,
    channel: "好物"
  },
  {
    title: "露营烧烤｜夜里那点炭火和灯光",
    prompt: "barbecue skewers over charcoal fire with camping lantern at night, warm glow, outdoor camping",
    size: "portrait_16_9",
    author: "阿哲",
    likes: 11250,
    channel: "美食"
  },
  {
    title: "北欧风客厅｜灰色沙发这样搭最舒服",
    prompt: "nordic living room with grey sofa and geometric rug, bright airy space, interior design",
    size: "landscape_4_3",
    author: "慢生活研究所",
    likes: 9034,
    channel: "家居"
  },
  {
    title: "手冲咖啡教程｜注水这一步决定了风味",
    prompt: "pouring hot water from gooseneck kettle over coffee dripper, steam rising, dark moody background",
    size: "portrait_4_3",
    author: "小鹿的日常",
    likes: 6285,
    channel: "美食"
  }
]

note_seeds.each_with_index do |seed, index|
  note = Note.find_or_initialize_by(title: seed[:title])
  note.assign_attributes(
    cover_url: "#{note_image_api}?prompt=#{ERB::Util.url_encode(seed[:prompt])}&image_size=#{seed[:size]}",
    cover_ratio: note_cover_ratios.fetch(seed[:size]),
    author_name: seed[:author],
    avatar_color: note_avatar_colors[index % note_avatar_colors.length],
    likes_count: seed[:likes],
    channel: seed[:channel],
    sort: index + 1
  )
  note.save!
end

# channel_list 首个是虚拟频道「推荐」，真实频道数需减 1
puts "内容初始化完成：#{Note.count} 条内容 / #{Note.channel_list.size - 1} 个频道"
