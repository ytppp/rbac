<template>
  <div class="page-container">
    <!-- 核心指标 -->
    <div v-loading="loading" class="stat-grid">
      <div v-for="card in cards" :key="card.label" class="stat-card">
        <p class="stat-label">{{ card.label }}</p>
        <p class="stat-value">{{ card.value }}</p>
      </div>
    </div>

    <!-- 近 14 天趋势 -->
    <el-card shadow="never" class="trend-card">
      <template #header>
        <div class="card-head">
          <span>近 14 天趋势</span>
          <div class="legend">
            <span><i class="dot dot--notes" /> 新增内容</span>
            <span><i class="dot dot--likes" /> 新增点赞</span>
          </div>
        </div>
      </template>

      <div v-if="stats" class="trend">
        <div v-for="day in stats.trend" :key="day.date" class="trend-col">
          <div class="trend-bars">
            <span
              class="bar bar--notes"
              :style="{ height: barHeight(day.notes) }"
              :title="`新增内容 ${day.notes}`"
            />
            <span
              class="bar bar--likes"
              :style="{ height: barHeight(day.likes) }"
              :title="`新增点赞 ${day.likes}`"
            />
          </div>
          <span class="trend-date">{{ day.date.slice(5) }}</span>
        </div>
      </div>
      <el-empty v-else description="暂无数据" :image-size="72" />
    </el-card>

    <!-- 当前账号信息 -->
    <el-card shadow="never" class="welcome-card">
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
import { computed, onMounted, ref } from 'vue'
import { fetchDashboardStats, type DashboardStats } from '@/api/dashboard'
import { useUserStore } from '@/stores/user'
import { formatTime } from '@/utils/format'

const userStore = useUserStore()
const stats = ref<DashboardStats | null>(null)
const loading = ref(false)

const cards = computed(() => {
  if (!stats.value) return []

  return [
    { label: '内容总数', value: stats.value.notes.total },
    { label: '已发布', value: stats.value.notes.published },
    { label: '待审内容', value: stats.value.notes.pending },
    { label: '用户数', value: stats.value.users.total },
    { label: '总点赞', value: stats.value.likes },
    { label: '待处理举报', value: stats.value.pending_reports }
  ]
})

/** 柱状条高度按 14 天内的最大值归一化 */
const maxTrend = computed(() => {
  const values = stats.value?.trend.flatMap((day) => [day.notes, day.likes]) ?? []
  return Math.max(1, ...values)
})

function barHeight(value: number) {
  return `${Math.round((value / maxTrend.value) * 100)}%`
}

onMounted(async () => {
  loading.value = true
  try {
    stats.value = await fetchDashboardStats()
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.stat-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 12px;
}

@media (max-width: 1200px) {
  .stat-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .stat-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

.stat-card {
  padding: 16px 18px;
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
}

.stat-label {
  margin: 0;
  color: #909399;
  font-size: 12px;
}

.stat-value {
  margin: 6px 0 0;
  color: #303133;
  font-size: 24px;
  font-weight: 600;
}

.trend-card,
.welcome-card,
.permission-card {
  margin-top: 16px;
}

.card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.legend {
  display: flex;
  gap: 14px;
  color: #909399;
  font-size: 12px;
}

.legend span {
  display: inline-flex;
  align-items: center;
  gap: 5px;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 2px;
}

.dot--notes {
  background: #409eff;
}

.dot--likes {
  background: #f56c6c;
}

.trend {
  display: flex;
  align-items: flex-end;
  gap: 6px;
  height: 180px;
  padding-top: 8px;
}

.trend-col {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  height: 100%;
}

.trend-bars {
  display: flex;
  width: 100%;
  height: 100%;
  align-items: flex-end;
  justify-content: center;
  gap: 2px;
}

.bar {
  width: 40%;
  min-height: 2px;
  border-radius: 3px 3px 0 0;
  transition: height 0.2s ease;
}

.bar--notes {
  background: #409eff;
}

.bar--likes {
  background: #f56c6c;
}

.trend-date {
  color: #c0c4cc;
  font-size: 10px;
  white-space: nowrap;
}

.role-tag,
.permission-tag {
  margin: 0 8px 8px 0;
}
</style>
