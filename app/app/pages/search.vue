<template>
  <div class="w-full">
    <header class="search-head">
      <p class="travel-eyebrow m-0">SEARCH</p>
      <h1 class="search-title">{{ $t('search.title') }}</h1>
      <p v-if="q || tag" class="search-sub">
        <template v-if="tag">
          {{ $t('search.taggedWith', { tag }) }}
        </template>
        <template v-else>{{ $t('search.resultFor', { q }) }}</template>
      </p>
    </header>

    <div v-if="loading && !items.length" class="search-loading">
      <el-skeleton v-for="i in 5" :key="i" animated class="mb-4">
        <template #template>
          <div class="flex gap-4">
            <el-skeleton-item variant="image" class="!h-100px !w-150px !rounded-12px" />
            <div class="flex-1 space-y-2">
              <el-skeleton-item variant="text" class="!w-70%" />
              <el-skeleton-item variant="text" class="!w-40%" />
            </div>
          </div>
        </template>
      </el-skeleton>
    </div>

    <ul v-else-if="items.length" class="result-list">
      <li v-for="item in items" :key="item.id">
        <NuxtLink :to="localePath(`/explore/${item.id}`)" class="result-item">
          <el-image class="result-cover" :src="item.cover" :alt="item.title" fit="cover" />
          <div class="result-body">
            <h2 class="result-title">{{ item.title }}</h2>
            <div class="result-meta">
              <el-avatar
                :size="20"
                :src="item.author_avatar || undefined"
                :style="item.author_avatar ? undefined : { backgroundColor: item.avatar_color }"
              >
                {{ item.author.slice(0, 1) }}
              </el-avatar>
              <span>{{ item.author }}</span>
              <span class="result-dot" />
              <span>{{ item.channel }}</span>
              <span class="result-dot" />
              <span class="flex items-center gap-1">
                <icon name="i-carbon:favorite" />
                {{ item.likes }}
              </span>
            </div>
            <div v-if="item.tags?.length" class="result-tags">
              <el-tag v-for="tagName in item.tags" :key="tagName" size="small" round class="result-tag" @click.prevent>
                {{ tagName }}
              </el-tag>
            </div>
          </div>
        </NuxtLink>
      </li>
    </ul>

    <div v-else class="py-80px">
      <el-empty :description="$t('search.empty')" />
    </div>

    <div v-if="hasMore" class="search-more">
      <el-button text :loading="loading" @click="load()">{{ $t('common.loadMore') }}</el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { Note, PageMeta } from '~/composables/useNotes'
import { useAuth } from '~/composables/useAuth'

const route = useRoute()
const localePath = useLocalePath()
const { authHeaders } = useAuth()

const q = computed(() => String(route.query.q ?? '').trim())
const tag = computed(() => String(route.query.tag ?? '').trim())

const items = ref<Note[]>([])
const page = ref(0)
const hasMore = ref(false)
const loading = ref(false)

/** 加载结果：reset 为 true 时从第一页重新取 */
async function load(reset = false) {
  if (loading.value) return

  loading.value = true
  try {
    const pageNo = reset ? 1 : page.value + 1
    const result = await $fetch<{ items: Note[], meta: PageMeta }>('/notes', {
      baseURL: useApiBase(),
      headers: authHeaders(),
      query: { keyword: q.value, tag: tag.value, page: pageNo, per_page: 12 },
    })

    items.value = reset ? result.items : [...items.value, ...result.items]
    page.value = result.meta.page
    hasMore.value = result.meta.page < result.meta.total_pages
  } finally {
    loading.value = false
  }
}

// 搜索词 / 标签变化时重新拉取
watch([q, tag], () => {
  items.value = []
  page.value = 0
  hasMore.value = false
  load(true)
})

onMounted(() => load(true))
</script>

<style scoped>
.search-head {
  margin-bottom: 18px;
}

.search-title {
  margin: 6px 0 4px;
  color: var(--c-ink-1);
  font-size: 24px;
  font-weight: 600;
}

.search-sub {
  margin: 0;
  color: var(--c-ink-3);
  font-size: 13px;
}

.search-loading {
  padding-top: 8px;
}

.result-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin: 0;
  padding: 0;
  list-style: none;
}

/* 列表项：左侧封面 + 右侧文字，和瀑布流区分开 */
.result-item {
  display: flex;
  gap: 16px;
  padding: 12px;
  overflow: hidden;
  border: 1px solid var(--c-line);
  border-radius: 16px;
  background: var(--c-card);
  box-shadow: 0 2px 8px var(--c-shadow);
  text-decoration: none;
  transition: border-color 0.15s ease, transform 0.15s ease;
}

.result-item:hover {
  border-color: var(--el-color-primary-light-7);
  transform: translateY(-2px);
}

.result-cover {
  width: 180px;
  height: 120px;
  flex: none;
  border-radius: 12px;
  overflow: hidden;
}

.result-cover :deep(.el-image__inner) {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.result-body {
  min-width: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 10px;
}

.result-title {
  margin: 0;
  color: var(--c-ink-1);
  font-size: 16px;
  font-weight: 600;
  line-height: 1.5;
}

.result-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  color: var(--c-ink-3);
  font-size: 12px;
}

.result-dot {
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: var(--c-ink-3);
  opacity: 0.45;
}

.result-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.result-tag {
  cursor: default;
}

.search-more {
  display: flex;
  justify-content: center;
  margin-top: 16px;
}

@media (max-width: 640px) {
  .result-cover {
    width: 112px;
    height: 84px;
  }

  .result-title {
    font-size: 14px;
  }
}
</style>
