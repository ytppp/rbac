# 初始化数据脚本（种子数据）。
#
# 执行：bin/rails db:seed
# 本项目在容器启动时由 docker/entrypoint.sh 自动执行一次。
#
# 关键设计：整个脚本用 find_or_initialize_by + save! 写成「幂等」的 ——
# 意思是跑一次和跑十次结果完全一样，已存在的记录会被更新而不是重复插入。
# 这样容器反复重启也不会产生重复的权限节点或账号。
#
# find_or_initialize_by(code: xxx) 的含义：
#   先按条件去数据库找；找到就返回这条记录（此时是「已持久化」状态），
#   找不到就 new 一个未保存的对象（内存里），名字里的 initialize 就是指这一步。
# 之后再 assign_attributes 赋值、save! 保存，两种情况就都能正确处理了。

# ---------- 权限树 ----------
# 用嵌套的 Hash 描述整棵权限树，children 里放子节点。
# 好处是「结构一目了然」，写出来的形状和最终前端的菜单树是一致的。
PERMISSION_TREE = [
  {
    name: "仪表盘",
    code: "dashboard",
    type: :menu,                       # :menu 是 Ruby 的符号（symbol），本质是一个轻量的不可变字符串
    path: "/dashboard",
    component: "dashboard/index",
    icon: "Odometer",                  # Element Plus 的图标组件名，前端据此渲染图标
    sort: 1,
    children: []
  },
  {
    name: "系统管理",
    code: "system",
    type: :menu,
    path: "/system",
    component: nil,                    # 留空表示这一级只是「目录」，本身没有页面
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
          # 这三个是「按钮级」权限：既控制前端按钮显隐，也是后端 authorize! 的校验依据
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
  }
].freeze   # freeze 表示「冻结」，防止后面不小心改到这个常量

# 递归函数：把上面那棵树写进数据库。
# 参数 parent 是「当前这批节点的上级对象」，第一次调用时传 nil（即根节点）。
def seed_permissions(nodes, parent = nil)
  nodes.each do |node|
    permission = Permission.find_or_initialize_by(code: node[:code])
    # assign_attributes 一次性批量赋值，比逐个 permission.name = ... 清爽。
    # node[:xxx] 是取 Hash 的值；node[:xxx] 不存在时返回 nil，
    # 所以下面用了 `|| :menu`、`|| 0` 这类默认值兜底。
    permission.assign_attributes(
      name: node[:name],
      type: node[:type] || :menu,
      parent: parent,                  # 直接赋对象，Rails 会自动取出它的 id 存进 parent_id
      path: node[:path],
      component: node[:component],
      icon: node[:icon],
      sort: node[:sort] || 0,
      status: :enabled
    )
    permission.save!
    # 递归处理子节点，把刚保存的这条记录当作它们的上级
    seed_permissions(node[:children] || [], permission)
  end
end

seed_permissions(PERMISSION_TREE)

# 取出所有权限 id，后面给超管角色「全量授权」时要用
all_permission_ids = Permission.pluck(:id)

# ---------- 角色 ----------
# 1) 超级管理员：虽然代码里超管会跳过权限校验，但仍然把权限全配上，
#    这样在「角色管理」页面看到的权限清单是完整的，不容易让人误会。
super_admin = Role.find_or_initialize_by(code: Role::SUPER_ADMIN_CODE)
super_admin.assign_attributes(
  name: "超级管理员",
  description: "拥有全部权限，且不受权限校验限制（内置角色）",
  status: :enabled,
  built_in: true                       # built_in 为 true 的角色不允许删除、不允许改 code
)
super_admin.save!
super_admin.permission_ids = all_permission_ids

# 2) 用户管理员：只有用户管理相关的权限，故意不给 user:delete，
#    这样能直观演示「同一页面里不同角色按钮不一样」的效果。
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
# where(code: [...]) 传数组相当于 SQL 的 IN，一次查出这些权限的 id
user_manager.permission_ids = Permission.where(code: user_manager_codes).pluck(:id)

# 3) 只读访客：只能看列表，不能做任何写操作
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
# 只在「新建账号」时才设置密码。
# 因为密码一旦用 has_secure_password 存进去就是不可逆的哈希，
# 每次跑 seed 都重设一遍既没必要，也会把用户自己改过的密码覆盖掉。
admin.password = "Admin@123456" if admin.new_record?
admin.save!
# 只在还没分配过角色时才分配，避免把管理员后来调整过的角色覆盖回去
admin.role_ids = [super_admin.id] if admin.user_roles.empty?

manager = User.find_or_initialize_by(email: "manager@example.com")
manager.assign_attributes(name: "用户管理员", status: :enabled)
manager.password = "Manager@123456" if manager.new_record?
manager.save!
manager.role_ids = [user_manager.id] if manager.user_roles.empty?

# puts 是 Ruby 的打印方法，把结果输出到终端，方便确认执行情况
puts "权限初始化完成：#{Permission.count} 个权限节点 / #{Role.count} 个角色 / #{User.count} 个账号"
puts "默认账号：admin@example.com / Admin@123456"
puts "默认账号：manager@example.com / Manager@123456"

# ---------- 内容社区（app 模块）----------
# 封面由文生图服务按提示词生成，换服务只需改 IMAGE_API_BASE
note_image_api = ENV.fetch("IMAGE_API_BASE", "https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image")

# 每种图片尺寸对应的宽高比，和下面每条数据的 size 字段配合使用。
# 写成 3.0 / 4 而不是 3 / 4 很重要：整数相除在 Ruby 里结果是 0，
# 必须有一个操作数是浮点数，结果才会是小数。
note_cover_ratios = {
  "square_hd" => 1.0,
  "square" => 1.0,
  "portrait_4_3" => 3.0 / 4,
  "portrait_16_9" => 9.0 / 16,
  "landscape_4_3" => 4.0 / 3,
  "landscape_16_9" => 16.0 / 9
}.freeze

# 作者头像的底色，按顺序循环取用（见下面 index % 长度）
note_avatar_colors = %w[#ff6b6b #f7a072 #f2b705 #06d6a0 #4cc9f0 #7b6cf6 #ef7bb0 #8ac926].freeze

# 每条内容包含两部分信息：
#   prompt / size  用于拼出封面图片地址（提示词 + 尺寸交给文生图服务）
#   其余字段        直接存入 notes 表
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

# each_with_index 遍历时同时拿到「元素」和「下标」，
# 下标从 0 开始，下面用它生成 sort 顺序和循环取头像颜色。
note_seeds.each_with_index do |seed, index|
  note = Note.find_or_initialize_by(title: seed[:title])
  note.assign_attributes(
    # ERB::Util.url_encode 把提示词里的空格、逗号等转义成 %20、%2C，
    # 否则拼出来的 URL 是非法地址，浏览器取不到图片。
    cover_url: "#{note_image_api}?prompt=#{ERB::Util.url_encode(seed[:prompt])}&image_size=#{seed[:size]}",
    cover_ratio: note_cover_ratios.fetch(seed[:size]),
    author_name: seed[:author],
    avatar_color: note_avatar_colors[index % note_avatar_colors.length],   # 取余让颜色循环使用
    likes_count: seed[:likes],
    channel: seed[:channel],
    sort: index + 1                     # 从 1 开始编号，保持列表顺序和这里写的一致
  )
  note.save!
end

# channel_list 返回的数组里第一个是虚拟频道「推荐」，不是真实数据，所以要减 1
puts "内容初始化完成：#{Note.count} 条内容 / #{Note.channel_list.size - 1} 个频道"
