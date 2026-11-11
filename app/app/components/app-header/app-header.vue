<template>
  <header ref="headerRef" class="headroom">
    <div class="header-shell">
      <div class="flex-x-center h-[64px]">
        <div class="content-width flex-x-between h-full">
          <NuxtLink :to="localePath('/')" class="flex flex-none items-center gap-10px text-ink-1 no-underline">
            <span class="travel-mark brand-mark">
              <icon name="i-carbon:compass" />
            </span>
            <span class="brand-text">
              <span class="brand-name">{{ $t('brand.name') }}</span>
              <span class="brand-sub">{{ $t('brand.sub') }}</span>
            </span>
          </NuxtLink>

          <div class="flex-y-center">
            <el-input
              v-model="keyword"
              class="search-input"
              :placeholder="$t('header.searchPlaceholder')"
              clearable
            >
              <template #prefix>
                <icon name="i-carbon:search" />
              </template>
            </el-input>

            <el-divider direction="vertical" />
            <theme-toggle />
            <el-divider direction="vertical" />
            <locale-toggle />
            <el-divider direction="vertical" />

            <div class="ml-auto flex flex-none items-center gap-14px">
              <template v-if="isLoggedIn">
                <el-button class="admin-entry" round @click="goAdmin">
                  <icon name="i-carbon:dashboard" />
                  <span class="ml-1 max-md:hidden">{{ $t('header.admin') }}</span>
                </el-button>
                <el-button type="primary" round>
                  <icon name="i-carbon:add" />
                  <span class="ml-1">{{ $t('header.publish') }}</span>
                </el-button>
                <!-- 已登录：头像 + 昵称，点开下拉可退出 -->
                <el-dropdown @command="handleUserCommand">
                  <div class="inline-flex cursor-pointer items-center gap-8px">
                    <el-avatar class="header-avatar" :size="34" :src="user?.avatar_url || undefined" :style="avatarStyle">
                      {{ avatarText }}
                    </el-avatar>
                    <span class="max-w-90px overflow-hidden text-13px text-ellipsis whitespace-nowrap max-md:hidden">
                      {{ user?.name }}
                    </span>
                  </div>
                  <template #dropdown>
                    <el-dropdown-menu>
                      <el-dropdown-item command="logout">
                        <icon name="i-carbon:logout" />
                        <span class="ml-1">{{ $t('header.logout') }}</span>
                      </el-dropdown-item>
                    </el-dropdown-menu>
                  </template>
                </el-dropdown>
              </template>
              <!-- 未登录：登录入口，登录后回到当前页 -->
              <el-button v-else type="primary" round @click="goLogin">{{ $t('header.login') }}</el-button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useFeed } from '~/composables/useFeed'
import { useAuth } from '~/composables/useAuth'
import Headroom from 'headroom.js'

const headerRef = useTemplateRef<HTMLElement>('headerRef')
let headroomInstance: Headroom | null = null

// 顶栏是否可见：headroom 隐藏/显示时同步给左右栏，
// 让它们的 sticky 停靠位置跟随变化（顶栏隐藏时贴到视口顶部）
const headerShown = useState('header-shown', () => true)

const { keyword } = useFeed()
const { user, token, isLoggedIn, fetchMe, logout } = useAuth()
const runtimeConfig = useRuntimeConfig()
const { t } = useI18n()

const route = useRoute()
const localePath = useLocalePath()

/** 登录后跳回当前页面 */
const loginTo = computed(() => localePath({ path: '/login', query: { redirect: route.fullPath } }))

/** 头像里的字：取昵称首字，没昵称就取邮箱首字母 */
const avatarText = computed(() => (user.value?.name || user.value?.email || t('header.me')).slice(0, 1))

/** 无上传头像时，回退到「渐变底 + 首字」 */
const avatarStyle = computed(() =>
  user.value?.avatar_url ? undefined : { background: 'linear-gradient(135deg,#7ec8d4,#0e7c86)' }
)

async function goLogin() {
  await navigateTo(loginTo.value)
}

/** 带 token 跳管理后台：admin 的 /sso 接住 token 后直接进首页 */
function goAdmin() {
  if (!token.value) return

  const base = String(runtimeConfig.public.adminBase || '').replace(/\/+$/, '')
  if (!base) return

  // token 放在 hash 里，不会进入服务端日志；admin 读取后会立即清掉地址
  window.location.href = `${base}/sso#token=${encodeURIComponent(token.value)}`
}

function handleUserCommand(command: string) {
  if (command === 'logout') logout()
}

// 刷新页面后 cookie 里还有 token，但内存里没有用户信息，这里补拉一次
onMounted(() => {
  if (token.value && !user.value) fetchMe()
  if (!headerRef.value) return
  headroomInstance = new Headroom(headerRef.value, {
    // 触发距离（像素）
    offset: 100,
    // 容差值（像素）
    tolerance: {
      up: 10, // 向上滚动触发距离
      down: 10, // 向下滚动触发距离
    },
    classes: {
      // when element is initialised
      initial: 'headroom',
      // when scrolling up
      pinned: 'headroom--pinned',
      // when scrolling down
      unpinned: 'headroom--unpinned',
      // when above offset
      top: 'headroom--top',
      // when below offset
      notTop: 'headroom--not-top',
    },
    // 顶栏固定/隐藏时同步状态，左右栏的 sticky 停靠位置随之调整
    onPin: () => { headerShown.value = true },
    onUnpin: () => { headerShown.value = false },
    onTop: () => { headerShown.value = true },
    onNotTop: () => { headerShown.value = true },
  })

  // 启动 Headroom
  headroomInstance.init()
})
</script>

<style scoped>
/* 初始状态 */
.headroom {
  @apply fixed top-0 left-0 w-full z-50 transition-all duration-300 will-change-transform;
}

/* 顶栏底板：暖白半透明 + 毛玻璃，滚动时内容透出来更像旅行杂志 */
.header-shell {
  background: var(--c-header-bg);
  backdrop-filter: saturate(180%) blur(14px);
  -webkit-backdrop-filter: saturate(180%) blur(14px);
  border-bottom: 1px solid var(--c-line);
}

/* 品牌标识：海岸青渐变方块 + 指南针，右侧两行小字 */
.brand-mark {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  font-size: 17px;
}

.brand-text {
  display: flex;
  flex-direction: column;
  line-height: 1.15;
}

.brand-name {
  font-size: 17px;
  font-weight: 600;
  letter-spacing: 1px;
}

.brand-sub {
  font-size: 9px;
  letter-spacing: 0.24em;
  color: var(--c-ink-3);
}

@media (max-width: 640px) {
  .brand-text {
    display: none;
  }
}

/* 固定在顶部 */
.headroom--pinned {
  @apply translate-y-0;
}
/* 取消固定 */
.headroom--unpinned {
  @apply -translate-y-full;
}
/* 在页面顶部时的状态 */
.headroom--top {
  /* @apply shadow-xl; */
}
/* 不在页面顶部时的状态 */
.headroom--not-top {
}
/* 在页面底部 */
.headroom--bottom {
}

/* 搜索框：暖白胶囊 + 细边框，聚焦时用主色描边 */
.search-input {
  @apply flex-1 max-w-560px;
}
.search-input :deep(.el-input__wrapper) {
  @apply h-38px rounded-19px px-14px;
  background-color: var(--c-card);
  box-shadow: 0 0 0 1px var(--c-line) inset;
}
.search-input :deep(.el-input__wrapper:hover) {
  box-shadow: 0 0 0 1px var(--el-color-primary-light-5) inset;
}
.search-input :deep(.el-input__wrapper.is-focus) {
  background-color: var(--c-card);
  box-shadow:
    0 0 0 1px var(--el-color-primary) inset,
    0 0 0 3px var(--el-color-primary-light-9);
}
.search-input :deep(.el-input__inner) {
  @apply h-full text-13px text-ink-1;
}
.search-input :deep(.el-input__prefix) {
  @apply text-ink-3;
}

.header-avatar {
  @apply text-13px;
}

/* 管理后台入口：低调的描边按钮，避免抢「发布」的主按钮 */
.admin-entry {
  border-color: var(--c-line);
  background: var(--c-card);
  color: var(--c-ink-2);
}

.admin-entry:hover {
  border-color: var(--el-color-primary-light-5);
  background: var(--el-color-primary-light-9);
  color: var(--el-color-primary);
}
</style>
