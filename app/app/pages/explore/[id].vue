<template>
  <div class="w-full">
    <!-- 内容不存在 / 请求失败 -->
    <div v-if="loadError || !note" class="py-80px">
      <el-empty :description="$t('detail.notFound')" />
    </div>

    <div v-else class="detail">
      <NuxtLink :to="localePath('/')" class="detail-back">
        <icon name="i-carbon:arrow-left" />
        <span>{{ $t('detail.back') }}</span>
      </NuxtLink>

      <div class="detail-grid">
        <!-- 视觉区：相册以浮层形式浮在地图右下角，可收起查看完整地图 -->
        <div v-if="hasVisual" class="visual-col">
          <div v-if="hasMap" class="map-stage">
            <app-map ref="mapRef" :trip="mapSegments" />

            <div class="map-stage__badge">
              <icon name="i-carbon:map" />
              <span>{{ $t('detail.map') }}</span>
              <span class="map-stage__dot" />
              <span>{{ $t('detail.segmentCount', { count: mapSegments.length }) }}</span>
            </div>

            <!-- 相册浮层：浮在地图右下角，默认展示 -->
            <transition name="album-pop">
              <div v-if="hasImages && showPhotos" class="map-stage__album">
                <div class="map-stage__album-head">
                  <span class="map-stage__album-title">
                    <icon name="i-carbon:image" />
                    <span>{{ activeBlockTitle || $t('detail.album') }}</span>
                  </span>
                  <span class="map-stage__album-tools">
                    <el-button
                      class="map-stage__icon-btn"
                      :title="$t('detail.hidePhotos')"
                      @click="showPhotos = false"
                    >
                      <icon name="i-carbon:view-off" />
                    </el-button>
                  </span>
                </div>

                <div v-if="activeImages.length" class="map-stage__album-body">
                  <note-gallery v-model:index="imageIndex" :images="activeImages" :alt="note.title" />
                </div>
                <div v-else class="map-stage__album-empty">
                  {{ $t('detail.noPhotosOther', { count: imageCount }) }}
                </div>
              </div>
            </transition>

            <!-- 图片隐藏后：右下角保留一个图标入口，点开恢复相册 -->
            <el-button
              v-if="hasImages && !showPhotos"
              circle
              class="map-stage__reopen"
              :title="$t('detail.showPhotos')"
              @click="showPhotos = true"
            >
              <icon name="i-carbon:image" />
            </el-button>
          </div>

          <!-- 没有地图时，相册独立成卡片 -->
          <div v-if="hasImages && !hasMap" class="album-card">
            <div class="album-card__head">
              <span class="album-card__title">
                <icon name="i-carbon:image" />
                <span>{{ activeBlockTitle || $t('detail.album') }}</span>
              </span>
              <span class="album-card__hint">
                <template v-if="activeImages.length">
                  {{ $t('detail.zoomIn') }}
                  <template v-if="activeImages.length > 1"> · {{ imageIndex + 1 }} / {{ activeImages.length }}</template>
                </template>
                <template v-else>{{ $t('detail.noPhotos') }}</template>
              </span>
            </div>

            <div v-if="activeImages.length" class="album-card__body">
              <note-gallery v-model:index="imageIndex" :images="activeImages" :alt="note.title" />
            </div>
            <div v-else class="album-card__empty">
              {{ $t('detail.noPhotosOther', { count: imageCount }) }}
            </div>
          </div>
        </div>

        <!-- 内容区：标题 + 目录 + 分段正文 -->
        <div class="content-col">
          <p class="travel-eyebrow mt-0 mb-8px">{{ note.channel }}</p>
          <h1 class="detail-title">{{ note.title }}</h1>

          <div class="detail-meta">
            <NuxtLink
              v-if="note.author_id"
              :to="localePath(`/author/${note.author_id}`)"
              class="author-link"
            >
              <el-avatar
                :size="20"
                :src="note.author_avatar || undefined"
                :style="note.author_avatar ? undefined : { backgroundColor: note.avatar_color }"
              >
                {{ note.author.slice(0, 1) }}
              </el-avatar>
              <span>{{ note.author }}</span>
            </NuxtLink>
            <span v-else class="flex items-center gap-6px">
              <el-avatar
                :size="20"
                :src="note.author_avatar || undefined"
                :style="note.author_avatar ? undefined : { backgroundColor: note.avatar_color }"
              >
                {{ note.author.slice(0, 1) }}
              </el-avatar>
              {{ note.author }}
            </span>
            <span class="meta-dot" />
            <span class="flex items-center gap-1">
              <icon name="i-carbon:favorite" />
              {{ note.likes }}
            </span>
            <template v-if="mapSegments.length">
              <span class="meta-dot" />
              <span class="flex items-center gap-1">
                <icon name="i-carbon:road" />
                {{ $t('detail.tripCount', { count: mapSegments.length }) }}
              </span>
            </template>

            <el-button
              round
              size="small"
              class="fav-btn"
              :class="{ 'is-active': favorited }"
              :loading="favoriteSubmitting"
              @click="toggleFavorite"
            >
              <icon :name="favorited ? 'i-carbon:bookmark-filled' : 'i-carbon:bookmark'" />
              <span class="ml-1">{{ favorited ? $t('detail.favorited') : $t('detail.favorite') }}</span>
            </el-button>
          </div>

          <!-- 标签：点击可查看同标签内容 -->
          <div v-if="note.tags?.length" class="detail-tags">
            <el-tag
              v-for="tagName in note.tags"
              :key="tagName"
              round
              size="small"
              class="detail-tag"
              @click="goTag(tagName)"
            >
              {{ tagName }}
            </el-tag>
          </div>

          <!-- 目录：每个段标题 + 段内小标题，点击切到对应段 -->
          <nav v-if="toc.length" class="toc">
            <p class="toc__title">
              <icon name="i-carbon:list-checked" />
              <span>{{ $t('detail.toc') }}</span>
            </p>
            <ul class="toc__list">
              <li v-for="item in toc" :key="item.id">
                <el-button
                  class="toc-item"
                  :class="{ 'is-active': item.id === activeHeadingId }"
                  :style="{ paddingLeft: `${10 + (item.level - 1) * 12}px` }"
                  @click="selectBlock(item.blockIndex, item.id)"
                >
                  <span class="toc__dot" />
                  <span class="toc__text">{{ item.text }}</span>
                </el-button>
              </li>
            </ul>
          </nav>

          <!-- 正文：开篇正文 + 按段渲染（段标题、段正文），点标题联动地图路段 / 图片 -->
          <article v-if="hasBody" class="md-body" @click="handleContentClick">
            <div v-if="intro.html" class="md-intro" v-html="intro.html" />
            <section v-for="block in renderedBlocks" :key="block.index" class="md-block">
              <h2 v-if="block.title" :id="`block-${block.index}`" class="md-block__title">
                {{ block.title }}
              </h2>
              <div v-if="block.html" v-html="block.html" />
            </section>
          </article>
          <el-empty v-else :description="$t('detail.noContent')" />

          <!-- 正文底部：举报入口 -->
          <div class="report-bar">
            <el-button text size="small" class="report-btn" @click="openReport()">
              <icon name="i-carbon:warning-alt" />
              <span class="ml-1">{{ $t('report.action') }}</span>
            </el-button>
          </div>

          <!-- 评论区 -->
          <note-comments :note-id="Number(noteId)" @report="openCommentReport" />
        </div>
      </div>

      <!-- 版权信息放在页面底部，宽度与首页「瀑布流 + 版权」一致 -->
      <site-info class="mt-10" />
    </div>

    <!-- 正文 Markdown 图片的大图预览 -->
    <el-image-viewer
      v-if="viewer.visible"
      :url-list="viewer.urls"
      :initial-index="viewer.index"
      teleported
      hide-on-click-modal
      @close="viewer.visible = false"
    />

    <!-- 举报弹窗（内容 / 评论共用） -->
    <note-report-dialog v-model:visible="reportVisible" :target="reportTarget" />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { NoteDetail } from '~/composables/useNotes'
import { useAuth } from '~/composables/useAuth'
import { useApiFetch } from '~/composables/useApiFetch'
import { useNoteSections } from '~/composables/useNoteSections'

// 版权信息改到页面底部展示，隐藏布局右侧的固定栏
definePageMeta({ hideSiteInfo: true })

const route = useRoute()
const localePath = useLocalePath()
const noteId = String(route.params.id)
const { isLoggedIn, authHeaders } = useAuth()
const { apiFetch } = useApiFetch()

const { data: note, error: loadError, refresh } = await useAsyncData<NoteDetail>(
  `note-detail-${noteId}`,
  () =>
    $fetch<NoteDetail>(`/notes/${noteId}`, {
      baseURL: useApiBase(),
      // SSR 的 HTML 会被 routeRules 缓存，因此服务端请求不带 token，
      // 避免把某个用户的收藏状态缓存给其他访客；客户端补水后再补拉个人状态。
      headers: import.meta.server ? {} : authHeaders(),
    }),
)

// 仅在「本次首屏来自 SSR」时为 true，客户端路由跳转不会重复请求
const needsAuthRefresh = useState(`note-detail-auth-${noteId}`, () => import.meta.server)

// 收藏：状态跟随详情接口返回，点击后立即更新
const favorited = ref(Boolean(note.value?.favorited))
const favoriteSubmitting = ref(false)

// SSR 首屏没有个人状态：登录用户在客户端补水后补拉一次，只更新收藏标记
onMounted(async () => {
  if (!needsAuthRefresh.value || !isLoggedIn.value) return

  needsAuthRefresh.value = false
  await refresh()
  favorited.value = Boolean(note.value?.favorited)
})

/** SEO：标题 / 摘要 / OG 卡片 / 结构化数据 */
const description = computed(() =>
  (note.value?.content || '').replace(/\s+/g, ' ').trim().slice(0, 120),
)

useSeoMeta({
  title: () => note.value?.title ?? '',
  description: () => description.value,
  ogTitle: () => note.value?.title ?? '',
  ogDescription: () => description.value,
  ogImage: () => note.value?.cover ?? '',
  ogType: 'article',
})

useHead({
  script: [
    {
      type: 'application/ld+json',
      innerHTML: () =>
        JSON.stringify({
          '@context': 'https://schema.org',
          '@type': 'Article',
          headline: note.value?.title ?? '',
          image: note.value?.cover ? [note.value.cover] : [],
          author: { '@type': 'Person', name: note.value?.author ?? '' },
          description: description.value,
        }),
    },
  ],
})

/** 点标签跳到搜索结果页，按标签浏览 */
function goTag(tagName: string) {
  navigateTo(localePath({ path: '/search', query: { tag: tagName } }))
}

// 举报：登录后可提交，同一内容 / 评论只能举报一次
const reportVisible = ref(false)
// 举报对象：内容或评论；默认是当前内容
const reportTarget = ref<{ type: 'note' | 'comment', id: number }>({ type: 'note', id: Number(noteId) })

function openReport(target?: { type: 'note' | 'comment', id: number }) {
  if (!isLoggedIn.value) {
    navigateTo(localePath({ path: '/login', query: { redirect: route.fullPath } }))
    return
  }

  reportTarget.value = target ?? { type: 'note', id: Number(noteId) }
  reportVisible.value = true
}

/** 评论区触发的举报 */
function openCommentReport(comment: { id: number }) {
  openReport({ type: 'comment', id: comment.id })
}

async function toggleFavorite() {
  if (!isLoggedIn.value) {
    await navigateTo(localePath({ path: '/login', query: { redirect: route.fullPath } }))
    return
  }

  favoriteSubmitting.value = true
  try {
    const result = await apiFetch<{ favorited: boolean }>(
      `/notes/${noteId}/${favorited.value ? 'unfavorite' : 'favorite'}`,
      { method: favorited.value ? 'DELETE' : 'POST', silent: true },
    )
    favorited.value = result.favorited
  } finally {
    favoriteSubmitting.value = false
  }
}

// 正文分段 / 地图行程 / 相册浮层 / 目录 —— 全部抽到 composable
const {
  mapSegments, hasMap, hasImages, hasVisual,
  activeImages, renderedBlocks, toc, hasBody, activeBlockTitle, imageCount, intro,
  imageIndex, activeHeadingId, showPhotos, viewer, mapRef,
  selectBlock,
} = useNoteSections(
  () => note.value?.sections ?? [],
  () => note.value?.content ?? '',
)

/** 正文交互：点图片看大图，点标题切到对应目录项 */
function handleContentClick(event: MouseEvent) {
  const target = event.target as HTMLElement | null

  // Markdown 正文里的图片：收集整篇文章的图片，从被点的那张开始预览
  if (target?.tagName === 'IMG') {
    const image = target as HTMLImageElement
    const article = image.closest('.md-body')
    if (!article) return

    const urls = Array.from(article.querySelectorAll('img')).map(
      (item) => (item as HTMLImageElement).src,
    )
    viewer.urls = urls
    viewer.index = Math.max(urls.indexOf(image.src), 0)
    viewer.visible = true
    return
  }

  const heading = target?.closest('h1,h2,h3,h4,h5,h6') as HTMLElement | null
  if (!heading?.id) {
    return
  }
  const item = toc.value.find((tocItem) => tocItem.id === heading.id)
  if (item) {
    selectBlock(item.blockIndex, item.id)
  }
}
</script>

<style scoped>
.detail-back {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  margin-bottom: 14px;
  color: var(--c-ink-3);
  font-size: 12px;
  text-decoration: none;
  transition: color 0.15s ease;
}

.detail-back:hover {
  color: var(--el-color-primary);
}

.detail-grid {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.content-col {
  min-width: 0;
}

@media (min-width: 1024px) {
  .detail-grid {
    flex-direction: row;
    align-items: flex-start;
    gap: 32px;
  }

  /* 桌面端让视觉区跟随滚动，读长文时地图和照片始终可见 */
  .visual-col {
    position: sticky;
    top: 86px;
    width: 46%;
    min-width: 0;
    flex: none;
  }

  .content-col {
    flex: 1;
  }
}

/* 地图：独立的旅行卡片 */
.map-stage {
  position: relative;
  height: 400px;
  overflow: hidden;
  border: 1px solid var(--c-line);
  border-radius: 26px;
  background: var(--c-surface);
  box-shadow: 0 20px 50px var(--c-shadow);
}

@media (min-width: 768px) {
  .map-stage {
    height: 520px;
  }
}

@media (min-width: 1024px) {
  .map-stage {
    height: 560px;
  }
}

/* 相册浮层：浮在地图右下角，毛玻璃卡片 */
.map-stage__album {
  position: absolute;
  right: 14px;
  bottom: 14px;
  z-index: 2;
  width: min(360px, calc(100% - 28px));
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.45);
  border-radius: 16px;
  background: var(--c-glass);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  box-shadow: 0 16px 40px rgba(10, 40, 42, 0.18);
}

.map-stage__album-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 6px 6px 6px 12px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.4);
}

.map-stage__album-title {
  display: inline-flex;
  min-width: 0;
  align-items: center;
  gap: 6px;
  color: var(--c-ink-2);
  font-size: 12px;
  font-weight: 600;
}

.map-stage__album-title span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.map-stage__album-tools {
  display: inline-flex;
  min-width: 0;
  flex: none;
  align-items: center;
  gap: 4px;
}

/* 头部图标按钮：与放大图标保持一致的纯图标样式 */
.map-stage__icon-btn {
  width: 26px;
  height: 26px;
  min-width: 26px;
  padding: 0;
  border-radius: 8px;
  font-size: 14px;
  --el-button-bg-color: transparent;
  --el-button-border-color: transparent;
  --el-button-text-color: var(--c-ink-3);
  --el-button-hover-bg-color: var(--c-surface);
  --el-button-hover-border-color: transparent;
  --el-button-hover-text-color: var(--c-ink-1);
  --el-button-active-bg-color: var(--c-surface);
  --el-button-active-border-color: transparent;
  --el-button-active-text-color: var(--c-ink-1);
  --el-button-outline-color: transparent;
}

.map-stage__album-body {
  height: 130px;
}

.map-stage__album-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 80px;
  color: var(--c-ink-3);
  font-size: 12px;
}

@media (min-width: 768px) {
  .map-stage__album-body {
    height: 160px;
  }
}

@media (min-width: 1024px) {
  .map-stage__album-body {
    height: 180px;
  }
}

/* 图片隐藏后：右下角图标入口 */
.map-stage__reopen {
  position: absolute;
  right: 14px;
  bottom: 14px;
  z-index: 3;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  font-size: 18px;
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  box-shadow: 0 6px 18px rgba(10, 40, 42, 0.18);
  transition: transform 0.15s ease;
  --el-button-bg-color: var(--c-glass);
  --el-button-border-color: rgba(255, 255, 255, 0.45);
  --el-button-text-color: var(--c-ink-1);
  --el-button-hover-bg-color: #20343a;
  --el-button-hover-border-color: #20343a;
  --el-button-hover-text-color: #ffffff;
  --el-button-active-bg-color: #20343a;
  --el-button-active-border-color: #20343a;
  --el-button-active-text-color: #ffffff;
  --el-button-outline-color: transparent;
}

.map-stage__reopen:hover {
  transform: translateY(-2px);
}

/* 浮层展开 / 收起动画 */
.album-pop-enter-active,
.album-pop-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.album-pop-enter-from,
.album-pop-leave-to {
  opacity: 0;
  transform: translateY(10px);
}

/* 没有地图时，相册独立成卡片 */
.album-card {
  overflow: hidden;
  border: 1px solid var(--c-line);
  border-radius: 22px;
  background: var(--c-card);
  box-shadow: 0 12px 30px var(--c-shadow);
}

.album-card__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--c-line);
}

.album-card__title {
  display: inline-flex;
  min-width: 0;
  align-items: center;
  gap: 6px;
  color: var(--c-ink-2);
  font-size: 12px;
  font-weight: 600;
}

.album-card__title span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.album-card__hint {
  flex: none;
  color: var(--c-ink-3);
  font-size: 11px;
}

.album-card__body {
  height: 300px;
}

.album-card__empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 120px;
  color: var(--c-ink-3);
  font-size: 12px;
}

@media (min-width: 768px) {
  .album-card__body {
    height: 420px;
  }
}

@media (min-width: 1024px) {
  .album-card__body {
    height: 520px;
  }
}

/* 左上角地图信息胶囊 */
.map-stage__badge {
  position: absolute;
  top: 14px;
  left: 14px;
  z-index: 2;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 11px;
  border: 1px solid rgba(255, 255, 255, 0.45);
  border-radius: 999px;
  background: var(--c-glass);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  color: var(--c-ink-1);
  font-size: 12px;
  font-weight: 500;
  box-shadow: 0 4px 14px rgba(10, 40, 42, 0.12);
}

.map-stage__dot {
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: var(--c-ink-3);
  opacity: 0.7;
}

.detail-title {
  margin: 0 0 14px;
  color: var(--c-ink-1);
  font-size: 26px;
  font-weight: 600;
  line-height: 1.35;
  letter-spacing: 0.01em;
}

@media (min-width: 768px) {
  .detail-title {
    font-size: 30px;
  }
}

.detail-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  margin-bottom: 20px;
  color: var(--c-ink-3);
  font-size: 12px;
}

/* 作者名可点进作者主页 */
.author-link {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: inherit;
  text-decoration: none;
  transition: color 0.15s ease;
}

.author-link:hover {
  color: var(--el-color-primary);
}

/* 收藏按钮靠右，已收藏用主色浅底 */
.fav-btn {
  margin-left: auto;
}

.fav-btn.is-active {
  --el-button-text-color: var(--el-color-primary);
  --el-button-border-color: var(--el-color-primary-light-5);
  --el-button-bg-color: var(--el-color-primary-light-9);
  --el-button-hover-bg-color: var(--el-color-primary-light-8);
  --el-button-hover-text-color: var(--el-color-primary);
  --el-button-hover-border-color: var(--el-color-primary-light-5);
}

/* 标签 chips */
.detail-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin: -6px 0 16px;
}

.detail-tag {
  cursor: pointer;
}

/* 正文底部的举报入口 */
.report-bar {
  display: flex;
  justify-content: flex-end;
  margin-top: 18px;
  padding-top: 14px;
  border-top: 1px dashed var(--c-line);
}

.report-btn {
  color: var(--c-ink-3);
  font-size: 12px;
}

.report-btn:hover {
  color: var(--el-color-danger);
}

.meta-dot {
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: var(--c-ink-3);
  opacity: 0.45;
}

/* 行程目录：浅色渐变卡片 + 圆点，像旅行路线清单 */
.toc {
  margin-bottom: 22px;
  padding: 14px 16px;
  border: 1px solid var(--c-line);
  border-radius: 16px;
  background: linear-gradient(160deg, var(--c-card) 0%, var(--c-surface) 100%);
}

.toc__title {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0 0 8px;
  color: var(--c-ink-2);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.04em;
}

.toc__list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.toc-item {
  display: flex;
  width: 100%;
  height: auto;
  justify-content: flex-start;
  gap: 8px;
  padding: 6px 10px;
  border-radius: 9px;
  font-size: 13px;
  line-height: 20px;
  text-align: left;
  transition: background-color 0.15s ease, color 0.15s ease;
  /* 用 el-button 的配色变量覆盖默认样式：透明底、悬停浅底 */
  --el-button-bg-color: transparent;
  --el-button-border-color: transparent;
  --el-button-text-color: var(--c-ink-2);
  --el-button-hover-bg-color: var(--c-surface-focus);
  --el-button-hover-border-color: transparent;
  --el-button-hover-text-color: var(--c-ink-1);
  --el-button-active-bg-color: var(--c-surface-focus);
  --el-button-active-border-color: transparent;
  --el-button-active-text-color: var(--c-ink-1);
  --el-button-outline-color: transparent;
}

/* el-button 会把内容包一层 span，这里让它撑满以保留「圆点 + 文字」布局 */
.toc-item :deep(> span) {
  display: flex;
  width: 100%;
  align-items: center;
  gap: 8px;
}

.toc__dot {
  width: 6px;
  height: 6px;
  flex: none;
  border-radius: 50%;
  background: var(--c-line);
  transition: background-color 0.15s ease, box-shadow 0.15s ease;
}

.toc-item.is-active {
  background: var(--el-color-primary-light-9);
  color: var(--el-color-primary);
  font-weight: 600;
  --el-button-hover-bg-color: var(--el-color-primary-light-9);
  --el-button-hover-text-color: var(--el-color-primary);
  --el-button-active-bg-color: var(--el-color-primary-light-9);
  --el-button-active-text-color: var(--el-color-primary);
}

.toc-item.is-active .toc__dot {
  background: var(--el-color-primary);
  box-shadow: 0 0 0 3px var(--el-color-primary-light-8);
}

/* Markdown 正文排版 */
.md-body {
  max-width: 820px;
  color: var(--c-ink-1);
  font-size: 15px;
  line-height: 1.9;
  word-break: break-word;
}

/* 开篇正文：用日落珊瑚做左侧强调，和正文段落区分开 */
.md-intro {
  margin: 0 0 20px;
  padding: 15px 18px;
  border-left: 3px solid var(--c-accent);
  border-radius: 0 14px 14px 0;
  background: var(--c-accent-soft);
  color: var(--c-ink-2);
  font-size: 14px;
  line-height: 1.85;
}

.md-block {
  margin-top: 6px;
}

.md-block__title {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin: 30px 0 12px;
  color: var(--c-ink-1);
  font-size: 18px;
  font-weight: 600;
  line-height: 1.5;
  scroll-margin-top: 90px;
  cursor: pointer;
  transition: color 0.15s ease;
}

.md-block__title::before {
  content: '';
  flex: none;
  width: 4px;
  height: 18px;
  margin-top: 5px;
  border-radius: 999px;
  background: var(--c-brand-gradient);
}

.md-block__title:hover {
  color: var(--el-color-primary);
}

.md-body :deep(h1),
.md-body :deep(h2),
.md-body :deep(h3),
.md-body :deep(h4),
.md-body :deep(h5),
.md-body :deep(h6) {
  margin: 22px 0 10px;
  font-weight: 600;
  line-height: 1.45;
  cursor: pointer;
  scroll-margin-top: 90px;
}

.md-body :deep(h1) {
  font-size: 21px;
}

.md-body :deep(h2) {
  font-size: 18px;
}

.md-body :deep(h3) {
  font-size: 16px;
}

.md-body :deep(h4),
.md-body :deep(h5),
.md-body :deep(h6) {
  font-size: 15px;
}

.md-body :deep(h1:hover),
.md-body :deep(h2:hover),
.md-body :deep(h3:hover),
.md-body :deep(h4:hover),
.md-body :deep(h5:hover),
.md-body :deep(h6:hover) {
  color: var(--el-color-primary);
}

.md-body :deep(p) {
  margin: 12px 0;
}

.md-body :deep(img) {
  max-width: 100%;
  border-radius: 12px;
  box-shadow: 0 8px 22px var(--c-shadow);
}

.md-body :deep(a) {
  color: var(--el-color-primary);
  text-underline-offset: 3px;
}

.md-body :deep(pre) {
  padding: 14px;
  overflow-x: auto;
  background: var(--c-surface);
  border-radius: 10px;
}

.md-body :deep(code) {
  padding: 1px 4px;
  background: var(--c-surface);
  border-radius: 4px;
  font-size: 13px;
}

.md-body :deep(blockquote) {
  margin: 14px 0;
  padding: 10px 14px;
  border-left: 3px solid var(--el-color-primary-light-5);
  border-radius: 0 10px 10px 0;
  background: var(--c-surface);
  color: var(--c-ink-2);
}

.md-body :deep(hr) {
  margin: 26px 0;
  border: none;
  border-top: 1px dashed var(--c-line);
}
</style>
