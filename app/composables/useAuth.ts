/**
 * 社区端的登录状态。
 *
 * 设计要点：
 *   1. 复用后端同一套账号体系 —— 登录走 POST /api/v1/auth/login，
 *      拿到的 JWT 和后台管理端完全一样，不需要另建一套用户表。
 *   2. token 存 cookie（而不是 localStorage），这样 SSR 首次渲染时
 *      服务端也能读到它，从而把「是否已登录」带进首屏。
 *   3. 用 useState 存一份内存状态，保证同一页面里多个组件（顶栏、卡片）
 *      读到的是同一份、且会一起响应式更新。
 */
export interface AuthUser {
  id: number
  email: string
  name: string
}

interface LoginResult {
  token: string
  expires_in: number
  user: AuthUser
}

const USER_CACHE_KEY = 'community_auth_user'

export function useAuth() {
  // cookie 用于「刷新后恢复」；12 小时和后端 JWT 的有效期保持一致
  const cookie = useCookie<string | null>('community_token', {
    maxAge: 60 * 60 * 12,
    sameSite: 'lax'
  })

  // useState 是 Nuxt 提供的「跨组件共享、且 SSR 与客户端互通」的状态容器。
  // 首次初始化时用 cookie 里的 token 兜底，这样刷新页面还能保持登录。
  const token = useState<string | null>(USER_CACHE_KEY + '_token', () => cookie.value ?? null)
  const user = useState<AuthUser | null>(USER_CACHE_KEY, () => null)

  const isLoggedIn = computed(() => !!token.value)

  /** 需要鉴权的请求头；未登录时返回空对象 */
  function authHeaders(): Record<string, string> {
    return token.value ? { Authorization: `Bearer ${token.value}` } : {}
  }

  async function login(email: string, password: string) {
    const baseURL = useApiBase()
    const result = await $fetch<LoginResult>('/auth/login', {
      baseURL,
      method: 'POST',
      body: { email, password }
    })

    token.value = result.token
    cookie.value = result.token // 写回 cookie，供刷新后恢复
    user.value = result.user
    return result
  }

  /** 用 token 换回当前用户信息（刷新页面后补一次，让顶栏显示昵称） */
  async function fetchMe() {
    if (!token.value) return null

    try {
      const baseURL = useApiBase()
      const result = await $fetch<{ user: AuthUser }>('/auth/me', {
        baseURL,
        headers: authHeaders()
      })
      user.value = result.user
      return result.user
    } catch {
      // token 已失效：直接当作未登录，清干净
      logout()
      return null
    }
  }

  function logout() {
    token.value = null
    cookie.value = null
    user.value = null
  }

  return { token, user, isLoggedIn, authHeaders, login, fetchMe, logout }
}
