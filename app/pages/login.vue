<template>
  <main class="flex min-h-[calc(100vh-64px)] items-center justify-center px-24px py-40px">
    <form class="w-full max-w-360px rounded-16px bg-card px-28px py-32px shadow-[0_12px_40px_rgba(0,0,0,0.08)]" @submit.prevent="handleSubmit">
      <h1 class="mt-0 mb-6px text-22px font-600">登录发现</h1>
      <p class="mt-0 mb-24px text-13px text-ink-3">登录后即可点赞喜欢的内容</p>

      <label class="mb-16px block">
        <span class="mb-6px block text-13px text-ink-2">邮箱</span>
        <input
          v-model="email"
          class="h-40px w-full rounded-10px border border-line bg-[#fafafa] px-14px text-14px text-ink-1 outline-none transition-colors duration-180 focus:border-brand focus:bg-white"
          type="email"
          autocomplete="username"
          placeholder="you@example.com"
        />
      </label>

      <label class="mb-16px block">
        <span class="mb-6px block text-13px text-ink-2">密码</span>
        <input
          v-model="password"
          class="h-40px w-full rounded-10px border border-line bg-[#fafafa] px-14px text-14px text-ink-1 outline-none transition-colors duration-180 focus:border-brand focus:bg-white"
          type="password"
          autocomplete="current-password"
          placeholder="请输入密码"
        />
      </label>

      <p v-if="error" class="mt-0 mb-14px text-13px text-brand">{{ error }}</p>

      <button
        class="h-42px w-full cursor-pointer rounded-21px border-0 bg-brand text-15px text-white transition-opacity duration-180 hover:opacity-90 disabled:opacity-60 disabled:cursor-default"
        type="submit"
        :disabled="submitting"
      >
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
