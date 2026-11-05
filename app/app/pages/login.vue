<template>
  <div class="login-page relative flex min-h-screen items-center justify-center px-24px py-40px">
    <!-- 左上角品牌 logo，右上角主题 / 语言切换 -->
    <NuxtLink to="/" class="absolute left-24px top-16px flex items-center gap-10px text-ink-1 no-underline">
      <span class="travel-mark h-30px w-30px rounded-9px text-17px">
        <icon name="i-carbon:compass" />
      </span>
      <span class="flex flex-col leading-[1.15] max-md:hidden">
        <span class="text-17px font-600 tracking-[1px]">发现</span>
        <span class="text-[9px] tracking-[0.24em] text-ink-3">TRAVEL NOTES</span>
      </span>
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
      class="auth-card w-full max-w-360px rounded-24px bg-card px-28px py-32px shadow-[0_20px_60px_var(--c-shadow)]"
      @submit.prevent="handleSubmit"
    >
      <div class="auth-tabs">
        <button type="button" :class="{ 'is-active': !isRegister }" @click="switchMode(false)">登录</button>
        <button type="button" :class="{ 'is-active': isRegister }" @click="switchMode(true)">注册</button>
      </div>

      <p class="travel-eyebrow mt-0 mb-8px">{{ isRegister ? 'JOIN THE JOURNEY' : 'WELCOME BACK' }}</p>
      <h1 class="mt-0 mb-6px text-22px font-600">{{ isRegister ? '加入发现' : '登录发现' }}</h1>
      <p class="mt-0 mb-24px text-13px text-ink-3">
        {{ isRegister ? '注册后即可发布旅行手记，并进入内容管理' : '登录后，收藏你走过的每一段旅程' }}
      </p>

      <el-form-item v-if="isRegister" label="昵称" prop="name">
        <el-input v-model="form.name" size="large" placeholder="怎么称呼你" maxlength="50" />
      </el-form-item>

      <el-form-item label="邮箱" prop="email">
        <el-input v-model="form.email" size="large" placeholder="you@example.com" autocomplete="username" />
      </el-form-item>

      <el-form-item label="密码" prop="password">
        <el-input
          v-model="form.password"
          type="password"
          size="large"
          :placeholder="isRegister ? '至少 6 位' : '请输入密码'"
          show-password
          :autocomplete="isRegister ? 'new-password' : 'current-password'"
        />
      </el-form-item>

      <el-form-item v-if="isRegister" label="确认密码" prop="password_confirmation">
        <el-input
          v-model="form.password_confirmation"
          type="password"
          size="large"
          placeholder="再输入一次密码"
          show-password
          autocomplete="new-password"
        />
      </el-form-item>

      <el-alert v-if="error" :title="error" type="error" :closable="false" show-icon class="mb-14px" />

      <el-button type="primary" round class="submit-btn" native-type="submit" :loading="submitting">
        {{ submitting ? (isRegister ? '注册中…' : '登录中…') : isRegister ? '注册并登录' : '登录' }}
      </el-button>
    </el-form>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { useAuth } from '~/composables/useAuth'

// 登录页不走默认布局，去掉顶栏与右侧栏
definePageMeta({ layout: false })

const route = useRoute()
const { login, register } = useAuth()

const formRef = ref<FormInstance>()
const isRegister = ref(false)
const form = reactive({
  name: '',
  email: '',
  password: '',
  password_confirmation: '',
})
const error = ref('')
const submitting = ref(false)

function validateConfirm(
  _rule: unknown,
  value: string,
  callback: (error?: Error) => void,
) {
  if (!value) {
    callback(new Error('请再次输入密码'))
    return
  }
  if (value !== form.password) {
    callback(new Error('两次输入的密码不一致'))
    return
  }
  callback()
}

const rules = computed<FormRules>(() => ({
  name: isRegister.value
    ? [{ required: true, message: '请输入昵称', trigger: 'blur' }]
    : [],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '邮箱格式不正确', trigger: ['blur', 'change'] },
  ],
  password: isRegister.value
    ? [
        { required: true, message: '请输入密码', trigger: 'blur' },
        { min: 6, message: '密码至少 6 位', trigger: 'blur' },
      ]
    : [{ required: true, message: '请输入密码', trigger: 'blur' }],
  password_confirmation: isRegister.value
    ? [{ validator: validateConfirm, trigger: 'blur' }]
    : [],
}))

function switchMode(value: boolean) {
  if (isRegister.value === value) return

  isRegister.value = value
  error.value = ''
  form.password = ''
  form.password_confirmation = ''
  formRef.value?.clearValidate()
}

async function handleSubmit() {
  error.value = ''
  if (!formRef.value) return

  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    if (isRegister.value) {
      await register({
        name: form.name.trim(),
        email: form.email.trim(),
        password: form.password,
        password_confirmation: form.password_confirmation,
      })
    } else {
      await login(form.email.trim(), form.password)
    }

    // 登录 / 注册成功：回到来源页（地址里带的 ?redirect=），没有就回首页
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/'
    await navigateTo(redirect)
  } catch (err: any) {
    // 后端把失败原因放在 { error: "..." } 里
    const fallback = isRegister.value ? '注册失败，请稍后重试' : '登录失败，请稍后重试'
    error.value = err?.data?.error || fallback
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
/* 登录页背景：沿用全站的暖沙底，再叠一层海面与日落光晕 */
.login-page {
  background-color: var(--c-page);
  background-image:
    radial-gradient(720px 420px at 78% 18%, rgba(126, 200, 212, 0.26), transparent 62%),
    radial-gradient(620px 360px at 18% 82%, rgba(242, 121, 90, 0.14), transparent 60%);
}

.auth-card {
  border: 1px solid var(--c-line);
}

/* 登录 / 注册切换：胶囊式分段控件，选中项浮起 */
.auth-tabs {
  display: flex;
  gap: 4px;
  margin-bottom: 22px;
  padding: 4px;
  border-radius: 999px;
  background: var(--c-surface);
}

.auth-tabs button {
  flex: 1;
  height: 32px;
  border: none;
  border-radius: 999px;
  background: transparent;
  color: var(--c-ink-2);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
}

.auth-tabs button.is-active {
  background: var(--c-card);
  color: var(--el-color-primary);
  font-weight: 600;
  box-shadow: 0 2px 8px var(--c-shadow);
}

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
  @apply rounded-10px px-14px;
  background-color: var(--c-surface);
  box-shadow: 0 0 0 1px var(--c-line) inset;
}
.auth-card :deep(.el-input__wrapper:hover) {
  box-shadow: 0 0 0 1px var(--c-line) inset;
}
.auth-card :deep(.el-input__wrapper.is-focus) {
  background-color: var(--c-card);
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
