<template>
  <div class="sso-page">
    <div class="sso-card">
      <span class="sso-spinner" />
      <span>{{ message }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { setToken } from '@/utils/auth'

const router = useRouter()
const message = ref('正在进入管理后台…')

onMounted(() => {
  // app 把 token 放在 hash 里传过来，hash 不会进入服务端日志
  const hash = window.location.hash.replace(/^#/, '')
  const token = new URLSearchParams(hash).get('token')

  if (!token) {
    message.value = '登录信息缺失，正在跳转登录页…'
    router.replace('/login')
    return
  }

  setToken(token)
  // 整页跳转，让 store 和动态路由都按新 token 重新初始化；同时清掉地址里的 token
  window.location.replace(`${import.meta.env.BASE_URL}dashboard`)
})
</script>

<style scoped>
.sso-page {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100vh;
  background: #f0f2f5;
}

.sso-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 20px 28px;
  border-radius: 12px;
  background: #fff;
  color: #606266;
  font-size: 14px;
  box-shadow: 0 12px 36px rgba(0, 0, 0, 0.08);
}

.sso-spinner {
  width: 18px;
  height: 18px;
  border: 2px solid #dcdfe6;
  border-top-color: #409eff;
  border-radius: 50%;
  animation: sso-spin 0.8s linear infinite;
}

@keyframes sso-spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
