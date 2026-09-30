import { ref } from 'vue'
import { defineStore } from 'pinia'
import type { RouteRecordRaw } from 'vue-router'
import { fetchMenus } from '@/api/permission'
import { buildDynamicRoutes } from '@/router/dynamic'
import type { MenuItem } from '@/types'

export const usePermissionStore = defineStore('permission', () => {
  /** 当前用户可见的菜单树（侧边栏数据源） */
  const menus = ref<MenuItem[]>([])
  /** 由菜单树生成的路由记录 */
  const dynamicRoutes = ref<RouteRecordRaw[]>([])
  const loaded = ref(false)

  async function generateRoutes() {
    const { items } = await fetchMenus()
    menus.value = items || []
    dynamicRoutes.value = buildDynamicRoutes(menus.value)
    loaded.value = true
    return dynamicRoutes.value
  }

  function reset() {
    menus.value = []
    dynamicRoutes.value = []
    loaded.value = false
  }

  return { menus, dynamicRoutes, loaded, generateRoutes, reset }
})
