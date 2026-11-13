<template>
  <div class="w-full">
    <!-- 用户信息 -->
    <section class="profile-head">
      <el-avatar
        :size="72"
        :src="user?.avatar_url || undefined"
        class="profile-avatar"
      >
        {{ initial }}
      </el-avatar>
      <div class="profile-info">
        <h1 class="profile-name">{{ user?.name }}</h1>
        <p class="profile-email">{{ user?.email }}</p>
      </div>
    </section>

    <!-- 我的发布 / 收藏 / 点赞 -->
    <el-tabs v-model="tab" class="profile-tabs" @tab-change="handleTabChange">
      <el-tab-pane :label="$t('profile.notes')" name="notes" />
      <el-tab-pane :label="$t('profile.favorites')" name="favorites" />
      <el-tab-pane :label="$t('profile.likes')" name="likes" />
    </el-tabs>

    <div v-if="loading && !notes.length" class="profile-loading">
      <el-skeleton :rows="4" animated />
    </div>

    <note-grid v-else-if="notes.length" :notes="notes" />

    <div v-else class="py-60px">
      <el-empty :description="emptyText" />
    </div>

    <div v-if="hasMore" class="profile-more">
      <el-button text :loading="loading" @click="load()">{{ $t('common.loadMore') }}</el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { Note, PageMeta } from '~/composables/useNotes'
import { useAuth } from '~/composables/useAuth'

const { user, isLoggedIn, authHeaders, fetchMe } = useAuth()
const { t } = useI18n()
const route = useRoute()
const localePath = useLocalePath()

// 个人中心必须登录
if (!isLoggedIn.value) {
  await navigateTo(localePath({ path: '/login', query: { redirect: route.fullPath } }))
}

// 刷新后可能只有 token 没有用户信息，补拉一次
if (!user.value) {
  await fetchMe()
}

type ProfileTab = 'notes' | 'favorites' | 'likes'

const tab = ref<ProfileTab>('notes')
const notes = ref<Note[]>([])
const page = ref(0)
const hasMore = ref(false)
const loading = ref(false)

const initial = computed(() => (user.value?.name || '?').slice(0, 1))

const emptyText = computed(() => {
  if (tab.value === 'favorites') return t('profile.emptyFavorites')
  if (tab.value === 'likes') return t('profile.emptyLikes')
  return t('profile.emptyNotes')
})

/** 加载当前 tab 的内容：reset 为 true 时从第一页重新取 */
async function load(reset = false) {
  if (loading.value) return

  loading.value = true
  try {
    const pageNo = reset ? 1 : page.value + 1
    const result = await $fetch<{ items: Note[], meta: PageMeta }>(`/me/${tab.value}`, {
      baseURL: useApiBase(),
      headers: authHeaders(),
      query: { page: pageNo, per_page: 12 },
    })

    notes.value = reset ? result.items : [...notes.value, ...result.items]
    page.value = result.meta.page
    hasMore.value = result.meta.page < result.meta.total_pages
  } finally {
    loading.value = false
  }
}

function handleTabChange() {
  notes.value = []
  page.value = 0
  hasMore.value = false
  load(true)
}

onMounted(() => load(true))
</script>

<style scoped>
.profile-head {
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 22px 24px;
  border: 1px solid var(--c-line);
  border-radius: 20px;
  background: var(--c-card);
  box-shadow: 0 8px 24px var(--c-shadow);
}

.profile-avatar {
  flex: none;
  background: var(--c-brand-gradient);
  color: #fff;
  font-size: 26px;
}

.profile-info {
  min-width: 0;
}

.profile-name {
  margin: 0;
  color: var(--c-ink-1);
  font-size: 22px;
  font-weight: 600;
}

.profile-email {
  margin: 4px 0 0;
  color: var(--c-ink-3);
  font-size: 13px;
}

.profile-tabs {
  margin-top: 18px;
}

.profile-tabs :deep(.el-tabs__item) {
  font-size: 14px;
}

.profile-loading {
  padding: 20px 0;
}

.profile-more {
  display: flex;
  justify-content: center;
  margin-top: 16px;
}
</style>
