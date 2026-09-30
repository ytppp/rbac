import type { Router } from 'vue-router'
import { usePermissionStore } from '@/stores/permission'
import { useUserStore } from '@/stores/user'
import { notFoundRoute } from './routes'

export function setupRouterGuard(router: Router) {
  router.beforeEach(async (to) => {
    const userStore = useUserStore()
    const permissionStore = usePermissionStore()

    // 未登录：放行白名单页面，其余跳转登录页并记住来源
    if (!userStore.token) {
      if (to.meta.public) return true
      return { path: '/login', query: { redirect: to.fullPath } }
    }

    // 已登录时不允许再进入登录页
    if (to.path === '/login') return { path: '/' }

    // 首次进入（或刷新页面）时按当前用户的菜单生成动态路由
    if (!permissionStore.loaded) {
      try {
        await userStore.fetchProfile()
        const routes = await permissionStore.generateRoutes()
        routes.forEach((route) => router.addRoute(route))
        // 必须在动态路由之后注册兜底路由，否则会拦截所有动态页面
        router.addRoute(notFoundRoute)
        return { path: to.fullPath, replace: true }
      } catch {
        userStore.reset()
        permissionStore.reset()
        return { path: '/login', query: { redirect: to.fullPath } }
      }
    }

    return true
  })

  router.afterEach((to) => {
    const appTitle = import.meta.env.VITE_APP_TITLE || '权限管理平台'
    const title = to.meta.title as string | undefined
    document.title = title ? `${title} - ${appTitle}` : appTitle
  })
}
