<template>
  <div class="w-full">
    <NuxtLink :to="localePath('/')" class="author-back">
      <icon name="i-carbon:arrow-left" />
      <span>{{ $t('detail.back') }}</span>
    </NuxtLink>

    <div v-if="error" class="py-60px">
      <el-empty :description="$t('author.notFound')" />
    </div>

    <template v-else>
      <!-- 作者信息 -->
      <section class="author-head">
        <el-avatar :size="72" :src="author?.avatar_url || undefined" class="author-avatar">
          {{ initial }}
        </el-avatar>
        <div class="author-info">
          <h1 class="author-name">{{ author?.name }}</h1>
          <p class="author-count">
            {{ $t('author.notesCount', { count: author?.notes_count ?? 0 }) }}
          </p>
        </div>
      </section>

      <note-grid v-if="notes.length" :notes="notes" class="mt-5" />

      <div v-else-if="!loading" class="py-60px">
        <el-empty :description="$t('author.empty')" />
      </div>

      <div v-if="hasMore" class="author-more">
        <el-button text :loading="loading" @click="loadMore">{{ $t('common.loadMore') }}</el-button>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import type { Note, PageMeta } from '~/composables/useNotes'
import { useAuth } from '~/composables/useAuth'

interface AuthorInfo {
  id: number
  name: string
  avatar_url: string | null
  notes_count: number
}

const route = useRoute()
const localePath = useLocalePath()
const { authHeaders } = useAuth()
const authorId = String(route.params.id)

const { data, error } = await useAsyncData(`author-${authorId}`, () =>
  $fetch<{ author: AuthorInfo, items: Note[], meta: PageMeta }>(`/authors/${authorId}`, {
    baseURL: useApiBase(),
    headers: authHeaders(),
  }),
)

const author = computed(() => data.value?.author ?? null)
const initial = computed(() => (author.value?.name || '?').slice(0, 1))

const notes = ref<Note[]>(data.value?.items ?? [])
const page = ref(data.value?.meta.page ?? 1)
const hasMore = ref(Boolean(data.value && data.value.meta.page < data.value.meta.total_pages))
const loading = ref(false)

async function loadMore() {
  if (loading.value) return

  loading.value = true
  try {
    const result = await $fetch<{ items: Note[], meta: PageMeta }>(`/authors/${authorId}`, {
      baseURL: useApiBase(),
      headers: authHeaders(),
      query: { page: page.value + 1 },
    })

    notes.value.push(...result.items)
    page.value = result.meta.page
    hasMore.value = result.meta.page < result.meta.total_pages
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.author-back {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  margin-bottom: 14px;
  color: var(--c-ink-3);
  font-size: 12px;
  text-decoration: none;
  transition: color 0.15s ease;
}

.author-back:hover {
  color: var(--el-color-primary);
}

.author-head {
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 22px 24px;
  border: 1px solid var(--c-line);
  border-radius: 20px;
  background: var(--c-card);
  box-shadow: 0 8px 24px var(--c-shadow);
}

.author-avatar {
  flex: none;
  background: var(--c-brand-gradient);
  color: #fff;
  font-size: 26px;
}

.author-info {
  min-width: 0;
}

.author-name {
  margin: 0;
  color: var(--c-ink-1);
  font-size: 22px;
  font-weight: 600;
}

.author-count {
  margin: 4px 0 0;
  color: var(--c-ink-3);
  font-size: 13px;
}

.author-more {
  display: flex;
  justify-content: center;
  margin-top: 16px;
}
</style>
