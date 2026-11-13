<template>
  <auth-shell>
    <el-form
      ref="formRef"
      :model="form"
      :rules="rules"
      label-position="top"
      @submit.prevent="handleSubmit"
    >
      <p class="travel-eyebrow mt-0 mb-8px">{{ $t('auth.loginEyebrow') }}</p>
      <h1 class="mt-0 mb-6px text-22px font-600">{{ $t('auth.loginTitle') }}</h1>
      <p class="mt-0 mb-24px text-13px text-ink-3">{{ $t('auth.loginDesc') }}</p>

      <el-form-item :label="$t('auth.email')" prop="email">
        <el-input
          v-model="form.email"
          size="large"
          :placeholder="$t('auth.emailPlaceholder')"
          autocomplete="username"
        />
      </el-form-item>

      <el-form-item :label="$t('auth.password')" prop="password">
        <el-input
          v-model="form.password"
          type="password"
          size="large"
          :placeholder="$t('auth.passwordPlaceholder')"
          show-password
          autocomplete="current-password"
        />
      </el-form-item>

      <el-alert v-if="error" :title="error" type="error" :closable="false" show-icon class="mb-14px" />

      <el-button type="primary" round class="submit-btn" native-type="submit" :loading="submitting">
        {{ submitting ? $t('auth.loggingIn') : $t('auth.login') }}
      </el-button>

      <p class="auth-switch">
        {{ $t('auth.noAccount') }}
        <NuxtLink :to="registerLink">{{ $t('auth.goRegister') }}</NuxtLink>
      </p>
    </el-form>
  </auth-shell>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { useAuth } from '~/composables/useAuth'

// 登录页不走默认布局，去掉顶栏与右侧栏
definePageMeta({ layout: false })

const route = useRoute()
const { login } = useAuth()
const { t } = useI18n()
const localePath = useLocalePath()

const formRef = ref<FormInstance>()
const form = reactive({ email: '', password: '' })
const error = ref('')
const submitting = ref(false)

/** 注册页链接：把当前页的 redirect 带过去，注册成功后还能回到来源页 */
const registerLink = computed(() =>
  localePath({
    path: '/register',
    query: typeof route.query.redirect === 'string' ? { redirect: route.query.redirect } : {},
  }),
)

const rules = computed<FormRules>(() => ({
  email: [
    { required: true, message: t('auth.emailRequired'), trigger: 'blur' },
    { type: 'email', message: t('auth.emailInvalid'), trigger: ['blur', 'change'] },
  ],
  password: [{ required: true, message: t('auth.passwordRequired'), trigger: 'blur' }],
}))

async function handleSubmit() {
  error.value = ''
  if (!formRef.value) return

  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    await login(form.email.trim(), form.password)

    // 登录成功：回到来源页（地址里带的 ?redirect=），没有就回首页
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/'
    await navigateTo(localePath(redirect))
  } catch (err: any) {
    // 后端把失败原因放在 { error: "..." } 里
    error.value = err?.data?.error || t('auth.loginFailed')
  } finally {
    submitting.value = false
  }
}
</script>
