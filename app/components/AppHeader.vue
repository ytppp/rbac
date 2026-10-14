<template>
  <header class="app-header">
    <div class="header-inner">
      <NuxtLink to="/" class="brand">
        <span class="brand-mark">发</span>
        <span class="brand-name">发现</span>
      </NuxtLink>

      <div class="search">
        <svg class="search-icon" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="7" />
          <path d="M20 20l-3.6-3.6" />
        </svg>
        <input
          v-model="keyword"
          class="search-input"
          type="search"
          placeholder="搜索你感兴趣的内容"
        />
      </div>

      <div class="header-actions">
        <button class="btn-publish" type="button">发布</button>

        <!-- 已登录：显示头像 + 昵称 + 退出 -->
        <div v-if="isLoggedIn" class="user-box">
          <span class="avatar">{{ avatarText }}</span>
          <span class="user-name">{{ user?.name }}</span>
          <button class="btn-logout" type="button" @click="logout">退出</button>
        </div>

        <!-- 未登录：给一个登录入口，登录后回到当前页 -->
        <NuxtLink v-else class="btn-login" :to="loginTo">登录</NuxtLink>
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

/** 登录后跳回当前页面 */
const loginTo = computed(() => ({ path: '/login', query: { redirect: route.fullPath } }))

/** 头像里的字：取昵称首字，没昵称就取邮箱首字母 */
const avatarText = computed(() => (user.value?.name || user.value?.email || '我').slice(0, 1))

// 刷新页面后 cookie 里还有 token，但内存里没有用户信息，这里补拉一次
onMounted(() => {
  if (token.value && !user.value) fetchMe()
})
</script>
