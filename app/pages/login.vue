<template>
  <div class="relative flex min-h-screen items-center justify-center bg-page px-24px py-40px">
    <!-- 左上角品牌 logo，右上角主题 / 语言切换 -->
    <NuxtLink to="/" class="absolute left-24px top-16px flex items-center gap-8px text-ink-1 no-underline">
      <span class="inline-flex h-30px w-30px items-center justify-center rounded-8px bg-brand text-15px font-600 text-white">发</span>
      <span class="text-17px font-600 tracking-[0.5px] max-md:hidden">发现</span>
    </NuxtLink>

    <div class="absolute right-24px top-16px flex-y-center">
      <theme-toggle />
      <el-divider direction="vertical" />
      <locale-toggle />
    </div>

    <el-form
      ref="formRef"
      :model="form"
      :rules="rules"
      label-position="top"
      class="auth-card w-full max-w-360px rounded-16px bg-card px-28px py-32px shadow-[0_12px_40px_rgba(0,0,0,0.08)]"
      @submit.prevent="handleSubmit"
    >
      <h1 class="mt-0 mb-6px text-22px font-600">登录发现</h1>
      <p class="mt-0 mb-24px text-13px text-ink-3">登录后即可点赞喜欢的内容</p>

      <el-form-item label="邮箱" prop="email">
        <el-input v-model="form.email" size="large" placeholder="you@example.com" autocomplete="username" />
      </el-form-item>

      <el-form-item label="密码" prop="password">
        <el-input
          v-model="form.password"
          type="password"
          size="large"
          placeholder="请输入密码"
          show-password
          autocomplete="current-password"
        />
      </el-form-item>

      <el-alert v-if="error" :title="error" type="error" :closable="false" show-icon class="mb-14px" />

      <el-button type="primary" round class="submit-btn" native-type="submit" :loading="submitting">
        {{ submitting ? '登录中…' : '登录' }}
      </el-button>
    </el-form>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { useAuth } from '~/composables/useAuth'

// 登录页不走默认布局，去掉顶栏与右侧栏
definePageMeta({ layout: false })

const route = useRoute()
const { login } = useAuth()

const formRef = ref<FormInstance>()
const form = reactive({ email: '', password: '' })
const error = ref('')
const submitting = ref(false)

const rules: FormRules = {
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '邮箱格式不正确', trigger: ['blur', 'change'] },
  ],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
}

async function handleSubmit() {
  error.value = ''
  if (!formRef.value) return

  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    await login(form.email.trim(), form.password)
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

<style scoped>
/* 表单卡片：间距与输入框样式贴近旧设计 */
.auth-card :deep(.el-form-item) {
  margin-bottom: 16px;
}
.auth-card :deep(.el-form-item__label) {
  @apply mb-6px h-auto text-13px text-ink-2;
  padding: 0;
  line-height: 1.4;
}
.auth-card :deep(.el-input__wrapper) {
  @apply rounded-10px bg-[#fafafa] px-14px;
  box-shadow: 0 0 0 1px #ededed inset;
}
.auth-card :deep(.el-input__wrapper:hover) {
  box-shadow: 0 0 0 1px #ededed inset;
}
.auth-card :deep(.el-input__wrapper.is-focus) {
  @apply bg-white;
  box-shadow: 0 0 0 1px var(--el-color-primary) inset;
}
.auth-card :deep(.el-input__inner) {
  @apply text-14px text-ink-1;
}
.submit-btn {
  @apply h-42px w-full;
  font-size: 15px;
}
</style>
