/**
 * 社区端的登录状态。
 *
 * 设计要点：
 *   1. 复用后端同一套账号体系 —— 登录走 POST /api/v1/auth/login，
 *      拿到的 JWT 和后台管理端完全一样，不需要另建一套用户表。
 *   2. 短效 access token + 长效 refresh token：
 *      access 默认 2 小时，refresh 默认 7 天；401 时自动续期并重放请求。
 *   3. token 存 cookie（而不是 localStorage），这样 SSR 首次渲染时
 *      服务端也能读到它，从而把「是否已登录」带进首屏。
 *   4. 用 useState 存一份内存状态，保证同一页面里多个组件（顶栏、卡片）
 *      读到的是同一份、且会一起响应式更新。
 */
export interface AuthUser {
  id: number
  email: string
  name: string
  /** 头像地址，未上传时为 null（回退到首字母展示） */
  avatar_url?: string | null
}

interface LoginResult {
  access_token: string
  refresh_token: string
  expires_in: number
  user: AuthUser
}

interface RegisterPayload {
  name: string
  email: string
  password: string
  password_confirmation: string
}

const USER_CACHE_KEY = 'community_auth_user'
const ACCESS_COOKIE = 'community_access_token'
const REFRESH_COOKIE = 'community_refresh_token'

export function useAuth() {
  // access 2 小时、refresh 7 天，与后端有效期保持一致
  const accessCookie = useCookie<string | null>(ACCESS_COOKIE, {
    maxAge: 60 * 60 * 2,
    sameSite: 'lax'
  })
  const refreshCookie = useCookie<string | null>(REFRESH_COOKIE, {
    maxAge: 60 * 60 * 24 * 7,
    sameSite: 'lax'
  })

  // useState 是 Nuxt 提供的「跨组件共享、且 SSR 与客户端互通」的状态容器。
  // 首次初始化时用 cookie 里的 token 兜底，这样刷新页面还能保持登录。
  const token = useState<string | null>(USER_CACHE_KEY + '_token', () => accessCookie.value ?? null)
  const refreshToken = useState<string | null>(USER_CACHE_KEY + '_refresh', () => refreshCookie.value ?? null)
  const user = useState<AuthUser | null>(USER_CACHE_KEY, () => null)

  const isLoggedIn = computed(() => !!token.value)

  /** 需要鉴权的请求头；未登录时返回空对象 */
  function authHeaders(): Record<string, string> {
    return token.value ? { Authorization: `Bearer ${token.value}` } : {}
  }

  /** 登录 / 注册 / 续期成功后统一写入本地登录态 */
  function applySession(result: LoginResult) {
    token.value = result.access_token
    accessCookie.value = result.access_token
    refreshToken.value = result.refresh_token
    refreshCookie.value = result.refresh_token
    user.value = result.user
  }

  // 并发 401 时共享同一个续期请求，避免同时打多次 /auth/refresh
  let refreshing: Promise<boolean> | null = null

  /** 用 refresh token 换新的一对 token；失败则清空登录态 */
  async function refreshSession(): Promise<boolean> {
    if (!refreshToken.value) return false

    if (!refreshing) {
      refreshing = $fetch<LoginResult>('/auth/refresh', {
        baseURL: useApiBase(),
        method: 'POST',
        body: { refresh_token: refreshToken.value }
      })
        .then((result) => {
          applySession(result)
          return true
        })
        .catch(() => {
          logout()
          return false
        })
        .finally(() => {
          refreshing = null
        })
    }

    return refreshing
  }

  async function login(email: string, password: string) {
    const baseURL = useApiBase()
    const result = await $fetch<LoginResult>('/auth/login', {
      baseURL,
      method: 'POST',
      body: { email, password }
    })

    applySession(result)
    return result
  }

  /** 注册成功即登录：后端会同时返回 token 与用户信息 */
  async function register(payload: RegisterPayload) {
    const baseURL = useApiBase()
    const result = await $fetch<LoginResult>('/auth/register', {
      baseURL,
      method: 'POST',
      body: payload
    })

    applySession(result)
    return result
  }

  function requestMe() {
    return $fetch<{ user: AuthUser }>('/auth/me', {
      baseURL: useApiBase(),
      headers: authHeaders()
    })
  }

  /** 用 token 换回当前用户信息（刷新页面后补一次，让顶栏显示昵称） */
  async function fetchMe() {
    if (!token.value) return null

    try {
      const result = await requestMe()
      user.value = result.user
      return result.user
    } catch {
      // access token 可能过期：先尝试续期，再补拉一次
      if (await refreshSession()) {
        try {
          const result = await requestMe()
          user.value = result.user
          return result.user
        } catch {
          // 续期后仍失败，按未登录处理
        }
      }

      logout()
      return null
    }
  }

  function logout() {
    token.value = null
    refreshToken.value = null
    accessCookie.value = null
    refreshCookie.value = null
    user.value = null
  }

  return {
    token,
    refreshToken,
    user,
    isLoggedIn,
    authHeaders,
    login,
    register,
    refreshSession,
    fetchMe,
    logout
  }
}
