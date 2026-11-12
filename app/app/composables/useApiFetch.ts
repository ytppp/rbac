/**
 * 统一的 API 请求封装：
 *   - 自动带上 access token
 *   - 401 时用 refresh token 续期并重放一次（不无限重试）
 *   - 续期失败才清登录态并跳登录页
 *   - 非 401 错误统一 toast（可用 silent 关掉）
 */
export function useApiFetch() {
  const baseURL = useApiBase()
  const { authHeaders, refreshSession, logout } = useAuth()
  const route = useRoute()
  const localePath = useLocalePath()

  async function apiFetch<T>(path: string, options: any = {}): Promise<T> {
    // silent / retried 是业务开关，不传给 $fetch
    const { silent, retried, ...fetchOptions } = options

    try {
      return (await $fetch(path, {
        ...fetchOptions,
        baseURL,
        headers: { ...authHeaders(), ...fetchOptions.headers },
      })) as T
    } catch (err: any) {
      const status = err?.response?.status
      const message = err?.data?.error || '请求失败'

      // access token 过期：续期成功后把原请求重放一次
      if (status === 401 && !retried && (await refreshSession())) {
        return apiFetch<T>(path, { ...options, retried: true })
      }

      if (status === 401) {
        logout()
        navigateTo(localePath({ path: '/login', query: { redirect: route.fullPath } }))
        throw err
      }

      if (!silent) {
        ElMessage.error(message)
      }
      throw err
    }
  }

  return { apiFetch }
}
