<template>
  <header class="sticky top-0 z-20 border-b border-line bg-[rgba(255,255,255,0.92)] [backdrop-filter:saturate(180%)_blur(12px)]">
    <div class="mx-auto flex h-64px max-w-[1500px] items-center gap-24px px-24px max-md:gap-12px max-md:px-16px">
      <!-- 登录页只保留顶栏框架，只展示品牌logo -->
      <NuxtLink to="/" class="flex flex-none items-center gap-8px text-ink-1 no-underline">
        <span class="inline-flex h-30px w-30px items-center justify-center rounded-8px bg-brand text-15px font-600 text-white">发</span>
        <span class="text-17px font-600 tracking-[0.5px] max-md:hidden">发现</span>
      </NuxtLink>

      <div v-if="!isLoginPage" class="relative max-w-560px flex-1">
        <svg
          class="absolute left-12px top-1/2 h-16px w-16px -translate-y-1/2 fill-none stroke-2 stroke-ink-3 [stroke-linecap:round]"
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          <circle cx="11" cy="11" r="7" />
          <path d="M20 20l-3.6-3.6" />
        </svg>
        <input
          v-model="keyword"
          class="h-38px w-full rounded-19px border-0 bg-[#f2f2f2] py-0 pl-34px pr-14px text-13px text-ink-1 outline-none transition-colors duration-180 focus:bg-[#ebebeb] [&::-webkit-search-cancel-button]:hidden"
          type="search"
          placeholder="搜索你感兴趣的内容"
        />
      </div>

      <div v-if="!isLoginPage" class="ml-auto flex flex-none items-center gap-14px">
        <template v-if="isLoggedIn">
          <button
            class="h-34px cursor-pointer rounded-17px border-0 bg-brand px-18px text-13px text-white transition-opacity duration-180 hover:opacity-88"
            type="button"
          >
            发布
          </button>
            <!-- 已登录：显示头像 + 昵称 + 退出 -->
            <div class="inline-flex items-center gap-8px">
              <!-- 有头像显示头像，没有则维持原来的「首字 + 渐变底」 -->
              <img
                v-if="user?.avatar_url"
                class="h-34px w-34px rounded-full object-cover"
                :src="user.avatar_url"
                :alt="user.name"
              />
              <span
                v-else
                class="inline-flex h-34px w-34px items-center justify-center rounded-full text-13px text-white [background:linear-gradient(135deg,#ffb199,#ff2e4d)]"
              >
                {{ avatarText }}
              </span>
              <span class="max-w-90px overflow-hidden text-13px text-ellipsis whitespace-nowrap max-md:hidden">{{ user?.name }}</span>
              <button
                class="inline-flex h-34px cursor-pointer items-center rounded-17px border-0 bg-[#f2f2f2] px-16px text-13px text-ink-2 transition-opacity duration-180 hover:opacity-88"
                type="button"
                @click="logout"
              >
                退出
              </button>
            </div>
        </template>
        <!-- 未登录：给一个登录入口，登录后回到当前页 -->
        <NuxtLink
          v-else
          class="inline-flex h-34px items-center rounded-17px border-0 bg-brand px-16px text-13px text-white no-underline transition-opacity duration-180 hover:opacity-88"
          :to="loginTo"
        >
          登录
        </NuxtLink>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useFeed } from '~/composables/useFeed'
import { useAuth } from '~/composables/useAuth'

const { keyword } = useFeed()
const { user, token, isLoggedIn, fetchMe, logout } = useAuth()

const route = useRoute()

/** 当前是否登录页：登录页隐藏品牌、搜索框和登录按钮 */
const isLoginPage = computed(() => route.path === '/login')

/** 登录后跳回当前页面 */
const loginTo = computed(() => ({ path: '/login', query: { redirect: route.fullPath } }))

/** 头像里的字：取昵称首字，没昵称就取邮箱首字母 */
const avatarText = computed(() => (user.value?.name || user.value?.email || '我').slice(0, 1))

// 刷新页面后 cookie 里还有 token，但内存里没有用户信息，这里补拉一次
onMounted(() => {
  if (token.value && !user.value) fetchMe()
})
</script>
