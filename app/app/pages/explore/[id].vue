<template>
  <div class="w-full">
    <!-- 内容不存在 / 请求失败 -->
    <div v-if="loadError || !note" class="py-80px">
      <el-empty description="内容不存在或已被删除" />
    </div>

    <div v-else class="detail">
      <NuxtLink to="/" class="detail-back">
        <icon name="i-carbon:arrow-left" />
        <span>返回发现</span>
      </NuxtLink>

      <div class="detail-grid">
        <!-- 视觉区：地图独占一块，照片放到下方独立相册卡片，互不遮挡 -->
        <div v-if="hasVisual" class="visual-col">
          <div v-if="hasMap" class="map-stage" :class="{ 'map-stage--album': hasImages }">
            <app-map ref="mapRef" :trip="mapSegments" />

            <div class="map-stage__badge">
              <icon name="i-carbon:map" />
              <span>行程地图</span>
              <span class="map-stage__dot" />
              <span>{{ mapSegments.length }} 段</span>
            </div>
          </div>

          <div v-if="hasImages" class="album-card" :class="{ 'album-card--solo': !hasMap }">
            <div class="album-card__head">
              <span class="album-card__title">
                <icon name="i-carbon:image" />
                <span>{{ activeBlockTitle || '旅途相册' }}</span>
              </span>
              <span class="album-card__hint">
                <template v-if="activeImages.length">
                  点击看大图
                  <template v-if="activeImages.length > 1"> · {{ imageIndex + 1 }} / {{ activeImages.length }}</template>
                </template>
                <template v-else>本段暂无图片</template>
              </span>
            </div>

            <div v-if="activeImages.length" class="album-card__body">
              <note-gallery v-model:index="imageIndex" :images="activeImages" :alt="note.title" />
            </div>
            <div v-else class="album-card__empty">
              本段暂无图片，其他段共 {{ imageCount }} 张
            </div>
          </div>
        </div>

        <!-- 内容区：标题 + 目录 + 分段正文 -->
        <div class="content-col">
          <p class="travel-eyebrow mt-0 mb-8px">{{ note.channel }}</p>
          <h1 class="detail-title">{{ note.title }}</h1>

          <div class="detail-meta">
            <span class="flex items-center gap-6px">
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
                {{ mapSegments.length }} 段行程
              </span>
            </template>
          </div>

          <!-- 目录：每个段标题 + 段内小标题，点击切到对应段 -->
          <nav v-if="toc.length" class="toc">
            <p class="toc__title">
              <icon name="i-carbon:list-checked" />
              <span>行程目录</span>
            </p>
            <ul class="toc__list">
              <li v-for="item in toc" :key="item.id">
                <button
                  type="button"
                  class="toc-item"
                  :class="{ 'is-active': item.id === activeHeadingId }"
                  :style="{ paddingLeft: `${10 + (item.level - 1) * 12}px` }"
                  @click="selectBlock(item.blockIndex, item.id)"
                >
                  <span class="toc__dot" />
                  <span class="toc__text">{{ item.text }}</span>
                </button>
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
          <el-empty v-else description="暂无正文内容" />
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
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import type { NoteDetail, NoteSection } from '~/composables/useNotes'
import type { TripSegment, TransportType } from '~/utils/amap/amap-extensions'
import { renderMarkdown } from '~/utils/markdown'

// 版权信息改到页面底部展示，隐藏布局右侧的固定栏
definePageMeta({ hideSiteInfo: true })

const route = useRoute()
const noteId = String(route.params.id)

const { data: note, error: loadError } = await useAsyncData<NoteDetail>(
  `note-detail-${noteId}`,
  () => $fetch<NoteDetail>(`/notes/${noteId}`, { baseURL: useApiBase() }),
)

/** 一段是否属于地图行程：type 非空且起终点齐全 */
function isTripSection(section: NoteSection): boolean {
  return Boolean(
    section.type &&
      section.type !== 'none' &&
      section.origin &&
      section.destination,
  )
}

/** 详情页按段展示，空段（没有标题、正文、行程、图片）直接跳过 */
const blocks = computed(() =>
  (note.value?.sections ?? []).filter((section) =>
    Boolean(
      section.title?.trim() ||
        section.content?.trim() ||
        isTripSection(section) ||
        section.images?.length,
    ),
  ),
)

const tripBlocks = computed(() =>
  blocks.value
    .map((section, index) => ({ section, index }))
    .filter(({ section }) => isTripSection(section)),
)

const mapSegments = computed<TripSegment[]>(() =>
  tripBlocks.value.map(({ section }) => ({
    type: section.type as TransportType,
    origin: section.origin!,
    destination: section.destination!,
    duration: section.duration,
    completed: section.completed,
  })),
)

/** 段落下标 -> 地图行程段下标（点目录时用来聚焦对应路段） */
const blockToTrip = computed(() => {
  const mapping = new Map<number, number>()
  tripBlocks.value.forEach(({ index }, tripIndex) => mapping.set(index, tripIndex))
  return mapping
})

const hasMap = computed(() => mapSegments.value.length > 0)
const hasImages = computed(() => blocks.value.some((section) => section.images?.length))
const hasVisual = computed(() => hasMap.value || hasImages.value)

// 当前段：默认停在第一组有图片的段，保证进页面就能看到图片
const firstImageBlock = blocks.value.findIndex((section) => section.images?.length)
const currentBlock = ref(firstImageBlock >= 0 ? firstImageBlock : 0)
const imageIndex = ref(0)
const activeHeadingId = ref<string | null>(null)

// 正文 Markdown 图片的大图预览（相册图片由 el-image 自带预览）
const viewer = reactive({
  visible: false,
  index: 0,
  urls: [] as string[],
})

/** 当前段对应的图片组；没有地图时回退到第一组有图的，避免左侧空一块 */
const activeImages = computed(() => {
  const current = blocks.value[currentBlock.value]?.images ?? []
  if (current.length) {
    return current
  }
  if (!hasMap.value) {
    return blocks.value.find((section) => section.images?.length)?.images ?? []
  }
  return []
})

watch(currentBlock, () => {
  imageIndex.value = 0
})

const mapRef = ref<any>(null)

/** 点击目录 / 正文标题：切到对应段、展示该段图片、聚焦该段地图路线（不滚动页面） */
function selectBlock(blockIndex: number, headingId?: string) {
  if (headingId) {
    activeHeadingId.value = headingId
  }

  if (blockIndex >= 0 && blockIndex < blocks.value.length) {
    currentBlock.value = blockIndex

    const tripIndex = blockToTrip.value.get(blockIndex)
    if (tripIndex !== undefined) {
      mapRef.value?.focusTripSegment?.(tripIndex)
    }
  }
}

// 开篇正文（可选）：不属于任何段，只随页面展示
const intro = computed(() => renderMarkdown(note.value?.content ?? '', 'intro-'))

interface RenderedBlock {
  index: number
  title: string
  html: string
  toc: ReturnType<typeof renderMarkdown>['toc']
}

const renderedBlocks = computed<RenderedBlock[]>(() =>
  blocks.value.map((section, index) => {
    const content = renderMarkdown(section.content ?? '', `block-${index}-`)
    return {
      index,
      title: (section.title ?? '').trim(),
      html: content.html,
      toc: content.toc,
    }
  }),
)

/** 当前段标题，用作下方相册卡片的标题 */
const activeBlockTitle = computed(() => renderedBlocks.value[currentBlock.value]?.title ?? '')

/** 全文图片总数，用于「本段暂无图片」的补充提示 */
const imageCount = computed(() =>
  blocks.value.reduce((total, section) => total + (section.images?.length ?? 0), 0),
)

interface PageTocItem {
  id: string
  text: string
  level: number
  /** -1 表示开篇正文，不绑定任何段 */
  blockIndex: number
}

const toc = computed<PageTocItem[]>(() => {
  const items: PageTocItem[] = intro.value.toc.map((item) => ({ ...item, blockIndex: -1 }))

  renderedBlocks.value.forEach((block) => {
    // 段标题本身也是目录项
    if (block.title) {
      items.push({
        id: `block-${block.index}`,
        text: block.title,
        level: 2,
        blockIndex: block.index,
      })
    }
    block.toc.forEach((item) => {
      items.push({ ...item, blockIndex: block.index })
    })
  })

  return items
})

const hasBody = computed(() => Boolean(intro.value.html) || renderedBlocks.value.some((block) => block.title || block.html))

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

/* 同页还有相册时，地图稍微收矮，保证「地图 + 相册」在桌面端能完整停在视口内 */
.map-stage--album {
  height: 360px;
}

@media (min-width: 768px) {
  .map-stage {
    height: 520px;
  }

  .map-stage--album {
    height: 440px;
  }
}

@media (min-width: 1024px) {
  .map-stage {
    height: 560px;
  }

  .map-stage--album {
    height: 420px;
  }
}

/* 相册卡片：移到地图下方，不再遮挡任何地图信息 */
.album-card {
  margin-top: 14px;
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
  height: 200px;
}

.album-card--solo .album-card__body {
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
    height: 220px;
  }

  .album-card--solo .album-card__body {
    height: 420px;
  }
}

@media (min-width: 1024px) {
  .album-card--solo .album-card__body {
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
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 6px 10px;
  border: none;
  border-radius: 9px;
  background: transparent;
  color: var(--c-ink-2);
  font-size: 13px;
  line-height: 20px;
  text-align: left;
  cursor: pointer;
  transition: background-color 0.15s ease, color 0.15s ease;
}

.toc__dot {
  width: 6px;
  height: 6px;
  flex: none;
  border-radius: 50%;
  background: var(--c-line);
  transition: background-color 0.15s ease, box-shadow 0.15s ease;
}

.toc-item:hover {
  background: var(--c-surface-focus);
  color: var(--c-ink-1);
}

.toc-item.is-active {
  background: var(--el-color-primary-light-9);
  color: var(--el-color-primary);
  font-weight: 600;
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
