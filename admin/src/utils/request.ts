import axios from 'axios'
import { ElMessage } from 'element-plus'
import { getRefreshToken, getToken, removeTokens, setTokens } from './auth'

const baseURL = import.meta.env.VITE_API_BASE_URL || '/api/v1'

const service = axios.create({
  baseURL,
  timeout: 15000
})

service.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// 并发 401 时共享同一个续期请求，避免同时打多次 /auth/refresh
let refreshing: Promise<string> | null = null

/** 用 refresh token 换新的 access token；refresh 本身失败则抛错交给外层清理登录态 */
function refreshAccessToken(): Promise<string> {
  const refreshToken = getRefreshToken()
  if (!refreshToken) return Promise.reject(new Error('没有可用的 refresh token'))

  if (!refreshing) {
    refreshing = axios
      // 用裸 axios，避免续期请求再次进入本拦截器造成死循环
      .post(`${baseURL}/auth/refresh`, { refresh_token: refreshToken })
      .then(({ data }) => {
        if (!data?.access_token || !data?.refresh_token) {
          throw new Error('token 续期失败')
        }
        setTokens(data.access_token, data.refresh_token)
        return data.access_token as string
      })
      .finally(() => {
        refreshing = null
      })
  }

  return refreshing
}

function redirectToLogin() {
  removeTokens()
  const redirect = encodeURIComponent(window.location.pathname + window.location.search)
  window.location.href = `/login?redirect=${redirect}`
}

service.interceptors.response.use(
  // 后端直接返回业务数据，这里剥掉 axios 的 data 包装
  (response) => response.data,
  async (error) => {
    const status = error.response?.status
    const message = error.response?.data?.error || error.message || '请求失败'
    const config = error.config as (typeof error.config & { __retried?: boolean }) | undefined

    // access token 过期：续期成功后把原请求重放一次（登录 / 续期接口本身不重试）
    if (
      status === 401 &&
      config &&
      !config.__retried &&
      !String(config.url || '').includes('/auth/')
    ) {
      try {
        const accessToken = await refreshAccessToken()
        config.__retried = true
        config.headers = { ...config.headers, Authorization: `Bearer ${accessToken}` }
        return service(config)
      } catch {
        // 续期失败，按未登录处理
      }
    }

    if (status === 401) {
      ElMessage.error(message)
      redirectToLogin()
    } else {
      ElMessage.error(message)
    }

    return Promise.reject(error)
  }
)

export default service
