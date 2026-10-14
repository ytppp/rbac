<template>
  <main class="auth">
    <form class="auth-card" @submit.prevent="handleSubmit">
      <h1 class="auth-title">登录发现</h1>
      <p class="auth-subtitle">登录后即可点赞喜欢的内容</p>

      <label class="auth-field">
        <span class="auth-label">邮箱</span>
        <input
          v-model="email"
          class="auth-input"
          type="email"
          autocomplete="username"
          placeholder="you@example.com"
        />
      </label>

      <label class="auth-field">
        <span class="auth-label">密码</span>
        <input
          v-model="password"
          class="auth-input"
          type="password"
          autocomplete="current-password"
          placeholder="请输入密码"
        />
      </label>

      <p v-if="error" class="auth-error">{{ error }}</p>

      <button class="auth-submit" type="submit" :disabled="submitting">
        {{ submitting ? '登录中…' : '登录' }}
      </button>
    </form>
  </main>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useAuth } from '~/composables/useAuth'

const route = useRoute()
const { login } = useAuth()

const email = ref('')
const password = ref('')
const error = ref('')
const submitting = ref(false)

async function handleSubmit() {
  error.value = ''

  if (!email.value.trim() || !password.value) {
    error.value = '请输入邮箱和密码'
    return
  }

  submitting.value = true
  try {
    await login(email.value.trim(), password.value)
    // 登录成功：回到来源页（登录页地址里带的 ?redirect=），没有就回首页
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/'
    await navigateTo(redirect)
  } catch (err: any) {
    // 后端把失败原因放在 { error: "..." } 里
    error.value = err?.data?.error || '登录失败，请稍后重试'
  } finally {
    submitting.value = false
  }
}
</script>
