<template>
  <div class="navbar-left">
    <el-breadcrumb separator="/">
      <el-breadcrumb-item v-for="(item, index) in breadcrumbs" :key="index">
        {{ item }}
      </el-breadcrumb-item>
    </el-breadcrumb>
  </div>

  <div class="navbar-right">
    <el-tag v-if="userStore.isSuperAdmin" type="danger" size="small" effect="plain">超级管理员</el-tag>
    <el-dropdown @command="handleCommand">
      <span class="navbar-user">
        <!-- 有头像显示头像，没有则维持原来的通用图标 -->
        <el-avatar v-if="userStore.userInfo?.avatar_url" :src="userStore.userInfo.avatar_url" :size="24" />
        <el-icon v-else><UserFilled /></el-icon>
        {{ userStore.displayName }}
        <el-icon><ArrowDown /></el-icon>
      </span>
      <template #dropdown>
        <el-dropdown-menu>
          <el-dropdown-item command="profile">个人中心</el-dropdown-item>
          <el-dropdown-item command="logout" divided>退出登录</el-dropdown-item>
        </el-dropdown-menu>
      </template>
    </el-dropdown>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { usePermissionStore } from '@/stores/permission'
import { useUserStore } from '@/stores/user'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()
const permissionStore = usePermissionStore()

const breadcrumbs = computed(() => {
  return route.matched
    .map((item) => item.meta?.title as string | undefined)
    .filter((title): title is string => Boolean(title))
})

async function handleCommand(command: string) {
  if (command === 'profile') {
    router.push('/profile')
    return
  }

  if (command === 'logout') {
    try {
      await ElMessageBox.confirm('确定要退出登录吗？', '提示', { type: 'warning' })
    } catch {
      return
    }
    await userStore.logout()
    permissionStore.reset()
    // 退出后整页刷新，清空已注册的动态路由，避免下一个账号看到上一个账号的菜单
    window.location.href = '/login'
  }
}
</script>

<style scoped>
.navbar-left {
  flex: 1;
}

.navbar-right {
  display: flex;
  align-items: center;
  gap: 12px;
}

.navbar-user {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  color: #303133;
  outline: none;
}
</style>
