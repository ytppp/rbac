<template>
  <header ref="headerRef" class="headroom">
    <div class="bg-card">
      <div class="flex-x-center h-[64px]">
        <div class="content-width flex-x-between h-full">
          <NuxtLink to="/" class="flex flex-none items-center gap-8px text-ink-1 no-underline">
            <span class="inline-flex h-30px w-30px items-center justify-center rounded-8px bg-brand text-15px font-600 text-white">发</span>
            <span class="text-17px font-600 tracking-[0.5px] max-md:hidden">发现</span>
          </NuxtLink>

          <div class="flex-y-center">
            <el-input
              v-model="keyword"
              class="search-input"
              placeholder="搜索你感兴趣的内容"
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
                <el-button type="primary" round>发布</el-button>
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
                        <span class="ml-1">退出登录</span>
                      </el-dropdown-item>
                    </el-dropdown-menu>
                  </template>
                </el-dropdown>
              </template>
              <!-- 未登录：登录入口，登录后回到当前页 -->
              <el-button v-else type="primary" round @click="goLogin">登录</el-button>
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

const route = useRoute()

/** 登录后跳回当前页面 */
const loginTo = computed(() => ({ path: '/login', query: { redirect: route.fullPath } }))

/** 头像里的字：取昵称首字，没昵称就取邮箱首字母 */
const avatarText = computed(() => (user.value?.name || user.value?.email || '我').slice(0, 1))

/** 无上传头像时，回退到「渐变底 + 首字」 */
const avatarStyle = computed(() =>
  user.value?.avatar_url ? undefined : { background: 'linear-gradient(135deg,#ffb199,#ff2e4d)' }
)

async function goLogin() {
  await navigateTo(loginTo.value)
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
  @apply fixed top-0 left-0 w-full z-50 border-0 border-b-2 border-solid border-line transition-all duration-300 will-change-transform;
}
/* 固定在顶部 */
.headroom--pinned {
  @apply translate-y-0 shadow-md;
}
/* 取消固定 */
.headroom--unpinned {
  @apply -translate-y-full shadow-md;
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

/* 搜索框：胶囊形、无边框、浅灰底，贴近旧设计 */
.search-input {
  @apply flex-1 max-w-560px;
}
.search-input :deep(.el-input__wrapper) {
  @apply h-38px rounded-19px px-14px;
  background-color: var(--c-surface);
  box-shadow: none;
}
.search-input :deep(.el-input__wrapper:hover) {
  box-shadow: none;
}
.search-input :deep(.el-input__wrapper.is-focus) {
  background-color: var(--c-surface-focus);
  box-shadow: none;
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
</style>
