import type { RouteRecordRaw } from 'vue-router'
import Layout from '@/layout/index.vue'
import ParentView from '@/layout/ParentView.vue'
import type { MenuItem } from '@/types'

/** src/views 下所有页面组件，key 形如 ../views/system/user/index.vue */
const viewModules = import.meta.glob('../views/**/*.vue')

/** 把组件路径字符串解析为异步组件 */
function resolveView(component?: string | null) {
  if (!component) return ParentView

  const key = `../views/${component}.vue`
  const loader = viewModules[key]

  if (!loader) {
    console.warn(`[router] 未找到页面组件：${component}，已回退到 404 页面`)
    return viewModules['../views/error/404.vue'] as () => Promise<unknown>
  }

  return loader as () => Promise<unknown>
}

function routeName(menu: MenuItem) {
  return `Menu_${menu.code.replace(/[:\-]/g, '_')}`
}

/** 拼接父路径与子路径 */
function joinPath(parentPath: string, childPath: string) {
  if (!childPath) return parentPath
  if (!parentPath) return childPath
  return `${parentPath.replace(/\/+$/, '')}/${childPath.replace(/^\/+/, '')}`
}

/** 将后端的绝对路径转换为相对于父级的路径 */
function toRelativePath(parentPath: string, childPath: string) {
  if (!childPath) return ''
  if (!parentPath) return childPath
  if (childPath === parentPath) return ''
  if (childPath.startsWith(`${parentPath}/`)) return childPath.slice(parentPath.length + 1)
  return childPath.replace(/^\/+/, '')
}

function menuMeta(menu: MenuItem) {
  return { title: menu.name, icon: menu.icon || undefined, code: menu.code }
}

/** 递归构建子路由 */
function buildChildRoute(menu: MenuItem, parentPath: string): RouteRecordRaw {
  const children = menu.children || []
  const hasChildren = children.length > 0

  const record = {
    path: toRelativePath(parentPath, menu.path),
    name: routeName(menu),
    component: hasChildren ? ParentView : resolveView(menu.component),
    meta: menuMeta(menu),
    children: hasChildren ? children.map((child) => buildChildRoute(child, menu.path)) : []
  } as unknown as RouteRecordRaw

  return record
}

/** 一级菜单：用 Layout 作为外壳，菜单自身作为子路由 */
function buildTopRoute(menu: MenuItem): RouteRecordRaw {
  const children = menu.children || []

  if (children.length === 0) {
    return {
      path: menu.path,
      name: routeName(menu),
      component: Layout,
      meta: menuMeta(menu),
      children: [
        {
          path: '',
          name: `${routeName(menu)}_Index`,
          component: resolveView(menu.component),
          meta: menuMeta(menu)
        } as unknown as RouteRecordRaw
      ]
    } as unknown as RouteRecordRaw
  }

  const childRoutes = children.map((child) => buildChildRoute(child, menu.path))
  const firstPath = childRoutes[0]?.path as string | undefined

  return {
    path: menu.path,
    name: routeName(menu),
    component: Layout,
    // 目录节点默认重定向到第一个可访问的子页面
    redirect: firstPath ? joinPath(menu.path, firstPath) : undefined,
    meta: menuMeta(menu),
    children: childRoutes
  } as unknown as RouteRecordRaw
}

export function buildDynamicRoutes(menus: MenuItem[]): RouteRecordRaw[] {
  return menus.map((menu) => buildTopRoute(menu))
}
