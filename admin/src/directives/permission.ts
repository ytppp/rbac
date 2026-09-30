import type { App, Directive } from 'vue'
import { useUserStore } from '@/stores/user'

/**
 * 按钮级权限指令
 * 用法： <el-button v-perm="'system:user:create'">新增</el-button>
 *       <el-button v-perm="['system:user:update', 'system:user:delete']">批量操作</el-button>
 * 不满足权限时直接从 DOM 中移除该元素
 */
const permission: Directive<HTMLElement, string | string[]> = {
  mounted(el, binding) {
    const userStore = useUserStore()

    if (!userStore.hasPermission(binding.value)) {
      el.parentNode?.removeChild(el)
    }
  }
}

export function setupDirectives(app: App) {
  app.directive('perm', permission)
}
