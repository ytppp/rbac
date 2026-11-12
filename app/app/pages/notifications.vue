<template>
  <div class="w-full">
    <header class="notice-head">
      <p class="travel-eyebrow m-0">NOTIFICATIONS</p>
      <div class="notice-head__row">
        <h1 class="notice-title">{{ $t('notification.title') }}</h1>
        <el-button v-if="hasUnread" text size="small" @click="markAllRead">
          {{ $t('notification.markAllRead') }}
        </el-button>
      </div>
    </header>

    <ul v-if="items.length" class="notice-list">
      <li v-for="item in items" :key="item.id">
        <button
          type="button"
          class="notice-item"
          :class="{ 'is-unread': !item.read }"
          @click="openItem(item)"
        >
          <el-avatar :size="36" :src="item.actor?.avatar_url || undefined" class="notice-avatar">
            {{ (item.actor?.name || '?').slice(0, 1) }}
          </el-avatar>
          <span class="notice-text">{{ textOf(item) }}</span>
          <span class="notice-time">{{ formatTime(item.created_at) }}</span>
        </button>
      </li>
    </ul>

    <div v-else-if="!loading" class="py-80px">
      <el-empty :description="$t('notification.empty')" />
    </div>

    <div v-if="hasMore" class="notice-more">
      <el-button text :loading="loading" @click="load()">{{ $t('common.loadMore') }}</el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useAuth } from '~/composables/useAuth'
import { useNotifications } from '~/composables/useNotifications'

interface NoticeItem {
  id: number
  action: 'comment' | 'like' | 'review'
  read: boolean
  created_at: string
  actor: { id: number, name: string, avatar_url: string | null } | null
  note: { id: number, title: string } | null
}

const { isLoggedIn, authHeaders } = useAuth()
const { unread, fetchUnread } = useNotifications()
const { t } = useI18n()
const route = useRoute()
const localePath = useLocalePath()

if (!isLoggedIn.value) {
  await navigateTo(localePath({ path: '/login', query: { redirect: route.fullPath } }))
}

const items = ref<NoticeItem[]>([])
const page = ref(0)
const hasMore = ref(false)
const loading = ref(false)

const hasUnread = computed(() => items.value.some((item) => !item.read) || unread.value > 0)

async function load(reset = false) {
  if (loading.value) return

  loading.value = true
  try {
    const pageNo = reset ? 1 : page.value + 1
    const result = await $fetch<{
      items: NoticeItem[]
      unread: number
      meta: { page: number, total_pages: number }
    }>('/notifications', {
      baseURL: useApiBase(),
      headers: authHeaders(),
      query: { page: pageNo, per_page: 15 },
    })

    items.value = reset ? result.items : [...items.value, ...result.items]
    page.value = result.meta.page
    hasMore.value = result.meta.page < result.meta.total_pages
    unread.value = result.unread
  } finally {
    loading.value = false
  }
}

function textOf(item: NoticeItem) {
  const name = item.actor?.name || t('notification.someone')
  const title = item.note?.title || ''
  return t(`notification.${item.action}`, { name, title })
}

/** 点击通知：标记已读并跳到对应内容 */
async function openItem(item: NoticeItem) {
  if (!item.read) {
    item.read = true
    await $fetch(`/notifications/${item.id}/read`, {
      baseURL: useApiBase(),
      method: 'PATCH',
      headers: authHeaders(),
    }).catch(() => undefined)
    await fetchUnread()
  }

  if (item.note?.id) {
    await navigateTo(localePath(`/explore/${item.note.id}`))
  }
}

async function markAllRead() {
  await $fetch('/notifications/read_all', {
    baseURL: useApiBase(),
    method: 'PATCH',
    headers: authHeaders(),
  }).catch(() => undefined)

  items.value = items.value.map((item) => ({ ...item, read: true }))
  await fetchUnread()
}

/** 相对时间，与评论区保持一致 */
function formatTime(value: string) {
  const diff = Date.now() - new Date(value).getTime()
  const minute = 60 * 1000
  const hour = 60 * minute
  const day = 24 * hour

  if (diff < minute) return t('time.justNow')
  if (diff < hour) return t('time.minutesAgo', { count: Math.floor(diff / minute) })
  if (diff < day) return t('time.hoursAgo', { count: Math.floor(diff / hour) })
  if (diff < 7 * day) return t('time.daysAgo', { count: Math.floor(diff / day) })

  return new Date(value).toLocaleDateString()
}

onMounted(() => load(true))
</script>

<style scoped>
.notice-head {
  margin-bottom: 16px;
}

.notice-head__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.notice-title {
  margin: 6px 0 0;
  color: var(--c-ink-1);
  font-size: 24px;
  font-weight: 600;
}

.notice-list {
  margin: 0;
  padding: 0;
  list-style: none;
}

/* 单条通知：头像 + 文案 + 时间 */
.notice-item {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 12px;
  padding: 14px 16px;
  border: 1px solid var(--c-line);
  border-radius: 14px;
  background: var(--c-card);
  color: var(--c-ink-1);
  font-size: 13px;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.15s ease, background-color 0.15s ease;
}

.notice-item + .notice-item {
  margin-top: 10px;
}

.notice-item:hover {
  border-color: var(--el-color-primary-light-7);
}

.notice-item.is-unread {
  background: var(--el-color-primary-light-9);
}

.notice-avatar {
  flex: none;
  background: var(--c-surface);
  color: var(--c-ink-2);
  font-size: 13px;
}

.notice-text {
  flex: 1;
  min-width: 0;
  line-height: 1.6;
}

.notice-time {
  flex: none;
  color: var(--c-ink-3);
  font-size: 11px;
}

.notice-more {
  display: flex;
  justify-content: center;
  margin-top: 16px;
}
</style>
