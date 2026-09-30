import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { getMe, login as loginApi, logout as logoutApi } from '@/api/auth'
import { getToken, removeToken, setToken } from '@/utils/auth'
import type { UserInfo } from '@/types'

export const SUPER_ADMIN_ROLE = 'super_admin'

export const useUserStore = defineStore('user', () => {
  const token = ref(getToken())
  const userInfo = ref<UserInfo | null>(null)
  const permissions = ref<string[]>([])
  const roles = ref<string[]>([])

  const isSuperAdmin = computed(() => roles.value.includes(SUPER_ADMIN_ROLE))
  const displayName = computed(() => userInfo.value?.name || userInfo.value?.email || '')

  function hasPermission(code?: string | string[]): boolean {
    if (!code) return true
    if (isSuperAdmin.value) return true

    const codes = Array.isArray(code) ? code : [code]
    return codes.some((item) => permissions.value.includes(item))
  }

  function hasAllPermissions(codes: string[]): boolean {
    if (isSuperAdmin.value) return true
    return codes.every((code) => permissions.value.includes(code))
  }

  async function login(payload: { email: string; password: string }) {
    const result = await loginApi(payload)
    token.value = result.token
    setToken(result.token)
    userInfo.value = result.user
    permissions.value = result.permissions || []
    roles.value = result.roles || []
    return result
  }

  async function fetchProfile() {
    const result = await getMe()
    userInfo.value = result.user
    permissions.value = result.permissions || []
    roles.value = result.roles || []
    return result
  }

  function reset() {
    token.value = ''
    userInfo.value = null
    permissions.value = []
    roles.value = []
    removeToken()
  }

  async function logout() {
    try {
      await logoutApi()
    } catch {
      // 忽略登出接口异常，本地状态照常清理
    } finally {
      reset()
    }
  }

  return {
    token,
    userInfo,
    permissions,
    roles,
    isSuperAdmin,
    displayName,
    hasPermission,
    hasAllPermissions,
    login,
    fetchProfile,
    logout,
    reset
  }
})
