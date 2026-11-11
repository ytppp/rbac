<template>
  <auth-shell>
    <el-form
      ref="formRef"
      :model="form"
      :rules="rules"
      label-position="top"
      @submit.prevent="handleSubmit"
    >
      <p class="travel-eyebrow mt-0 mb-8px">JOIN THE JOURNEY</p>
      <h1 class="mt-0 mb-6px text-22px font-600">加入发现</h1>
      <p class="mt-0 mb-24px text-13px text-ink-3">注册后即可发布旅行手记，并进入内容管理</p>

      <el-form-item label="昵称" prop="name">
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
          placeholder="至少 6 位"
          show-password
          autocomplete="new-password"
        />
      </el-form-item>

      <el-form-item label="确认密码" prop="password_confirmation">
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
        {{ submitting ? '注册中…' : '注册并进入' }}
      </el-button>

      <p class="auth-switch">
        已经有账号？
        <NuxtLink :to="loginLink">去登录</NuxtLink>
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
const loginLink = computed(() => ({
  path: '/login',
  query: typeof route.query.redirect === 'string' ? { redirect: route.query.redirect } : {},
}))

const rules: FormRules = {
  name: [{ required: true, message: '请输入昵称', trigger: 'blur' }],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '邮箱格式不正确', trigger: ['blur', 'change'] },
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码至少 6 位', trigger: 'blur' },
  ],
  password_confirmation: [
    {
      validator: (_rule, value, callback) => {
        if (!value) return callback(new Error('请再次输入密码'))
        if (value !== form.password) return callback(new Error('两次输入的密码不一致'))
        return callback()
      },
      trigger: 'blur',
    },
  ],
}

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
    await navigateTo(redirect)
  } catch (err: any) {
    error.value = err?.data?.error || '注册失败，请稍后重试'
  } finally {
    submitting.value = false
  }
}
</script>
