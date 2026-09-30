<template>
  <div class="page-container">
    <el-card shadow="never">
      <template #header>
        <span>欢迎回来，{{ userStore.displayName }}</span>
      </template>

      <el-descriptions :column="2" border>
        <el-descriptions-item label="邮箱">{{ userStore.userInfo?.email }}</el-descriptions-item>
        <el-descriptions-item label="昵称">{{ userStore.userInfo?.name }}</el-descriptions-item>
        <el-descriptions-item label="账号状态">
          {{ userStore.userInfo?.status_text }}
        </el-descriptions-item>
        <el-descriptions-item label="最近登录">
          {{ formatTime(userStore.userInfo?.last_login_at) }}
        </el-descriptions-item>
        <el-descriptions-item label="拥有角色" :span="2">
          <el-tag v-for="role in userStore.userInfo?.roles" :key="role.id" class="role-tag">
            {{ role.name }}
          </el-tag>
          <span v-if="!userStore.userInfo?.roles?.length">未分配角色</span>
        </el-descriptions-item>
      </el-descriptions>
    </el-card>

    <el-card shadow="never" class="permission-card">
      <template #header>
        <span>我的权限码（共 {{ userStore.permissions.length }} 项）</span>
      </template>

      <el-tag v-for="code in userStore.permissions" :key="code" class="permission-tag" type="info">
        {{ code }}
      </el-tag>
      <el-empty v-if="!userStore.permissions.length" description="暂无权限" />
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { useUserStore } from '@/stores/user'
import { formatTime } from '@/utils/format'

const userStore = useUserStore()
</script>

<style scoped>
.permission-card {
  margin-top: 16px;
}

.role-tag,
.permission-tag {
  margin: 0 8px 8px 0;
}
</style>
