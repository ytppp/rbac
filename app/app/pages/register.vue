<template>
  <auth-shell>
    <el-form
      ref="formRef"
      :model="form"
      :rules="rules"
      label-position="top"
      @submit.prevent="handleSubmit"
    >
      <p class="travel-eyebrow mt-0 mb-8px">{{ $t('auth.registerEyebrow') }}</p>
      <h1 class="mt-0 mb-6px text-22px font-600">{{ $t('auth.registerTitle') }}</h1>
      <p class="mt-0 mb-24px text-13px text-ink-3">{{ $t('auth.registerDesc') }}</p>

      <el-form-item :label="$t('auth.name')" prop="name">
        <el-input
          v-model="form.name"
          size="large"
          :placeholder="$t('auth.namePlaceholder')"
          maxlength="50"
        />
      </el-form-item>

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
          :placeholder="$t('auth.passwordNewPlaceholder')"
          show-password
          autocomplete="new-password"
        />
      </el-form-item>

      <el-form-item :label="$t('auth.confirmPassword')" prop="password_confirmation">
        <el-input
          v-model="form.password_confirmation"
          type="password"
          size="large"
          :placeholder="$t('auth.confirmPlaceholder')"
          show-password
          autocomplete="new-password"
        />
      </el-form-item>

      <el-alert v-if="error" :title="error" type="error" :closable="false" show-icon class="mb-14px" />

      <el-button type="primary" round class="submit-btn" native-type="submit" :loading="submitting">
        {{ submitting ? $t('auth.registering') : $t('auth.register') }}
      </el-button>

      <p class="auth-switch">
        {{ $t('auth.hasAccount') }}
        <NuxtLink :to="loginLink">{{ $t('auth.goLogin') }}</NuxtLink>
      </p>
    </el-form>
  </auth-shell>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { useAuth } from '~/composables/useAuth'

// 注册页与登录页一样，不走默认布局
definePageMeta({ layout: false })

const route = useRoute()
const { register } = useAuth()
const { t } = useI18n()
const localePath = useLocalePath()

const formRef = ref<FormInstance>()
const form = reactive({
  name: '',
  email: '',
  password: '',
  password_confirmation: '',
})
const error = ref('')
const submitting = ref(false)

/** 登录页链接：带上 redirect，登录后回到来源页 */
const loginLink = computed(() =>
  localePath({
    path: '/login',
    query: typeof route.query.redirect === 'string' ? { redirect: route.query.redirect } : {},
  }),
)

const rules = computed<FormRules>(() => ({
  name: [{ required: true, message: t('auth.nameRequired'), trigger: 'blur' }],
  email: [
    { required: true, message: t('auth.emailRequired'), trigger: 'blur' },
    { type: 'email', message: t('auth.emailInvalid'), trigger: ['blur', 'change'] },
  ],
  password: [
    { required: true, message: t('auth.passwordRequired'), trigger: 'blur' },
    { min: 6, message: t('auth.passwordMin'), trigger: 'blur' },
  ],
  password_confirmation: [
    {
      validator: (_rule, value, callback) => {
        if (!value) return callback(new Error(t('auth.confirmRequired')))
        if (value !== form.password) return callback(new Error(t('auth.confirmMismatch')))
        return callback()
      },
      trigger: 'blur',
    },
  ],
}))

async function handleSubmit() {
  error.value = ''
  if (!formRef.value) return

  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    // 注册接口会直接返回 token 和用户信息，成功后已是登录态
    await register({
      name: form.name.trim(),
      email: form.email.trim(),
      password: form.password,
      password_confirmation: form.password_confirmation,
    })

    // 注册即登录：回到来源页，没有就回首页
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/'
    await navigateTo(localePath(redirect))
  } catch (err: any) {
    error.value = err?.data?.error || t('auth.registerFailed')
  } finally {
    submitting.value = false
  }
}
</script>
