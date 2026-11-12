import { ElMessage } from 'element-plus'

/**
 * 统一的 API 请求封装：
 *   - 自动注入 baseURL + Authorization header
 *   - 401 自动清 token 跳登录
 *   - 其他错误默认 ElMessage 提示，传 silent:true 可静默（用于点赞/取消点赞这类"失败也不改状态"的场景）
 *
 * 用法：
 *   const { apiFetch } = useApiFetch()
 *   const note = await apiFetch<NoteDetail>('/notes/54')
 *   await apiFetch<{ liked: boolean }>(`/notes/${id}/like`, { method: 'POST' })
 *   await apiFetch(`/notes/${id}/like`, { method: 'POST', silent: true }) // 静默模式
 */
export function useApiFetch() {
  const baseURL = useApiBase()
  const { authHeaders, logout } = useAuth()
  const route = useRoute()

  async function apiFetch<T>(path: string, options: any = {}): Promise<T> {
    const { silent, ...fetchOptions } = options

    try {
      return await $fetch<T>(path, {
        ...fetchOptions,
        baseURL,
        headers: { ...authHeaders(), ...fetchOptions.headers },
      })
    } catch (err: any) {
      const status = err?.response?.status
      const message = err?.data?.error || '请求失败'

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
