import { computed, reactive, ref, watch } from 'vue'
import type { NoteSection } from '~/composables/useNotes'
import type { TripSegment, TransportType } from '~/utils/amap/amap-extensions'
import { renderMarkdown } from '~/utils/markdown'

interface RenderedBlock {
  index: number
  title: string
  html: string
  toc: ReturnType<typeof renderMarkdown>['toc']
}

interface PageTocItem {
  id: string
  text: string
  level: number
  /** -1 表示开篇正文，不绑定任何段 */
  blockIndex: number
}

export function useNoteSections(
  sections: () => NoteSection[],
  introContent: () => string,
) {
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
    sections().filter((section) =>
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
  const firstImageBlock = computed(() => blocks.value.findIndex((s) => s.images?.length))
  const currentBlock = ref(0)
  // 当数据加载完（blocks 从空变有），初始化到第一组有图片的段
  watch(
    () => blocks.value.length,
    (len) => {
      if (len > 0 && currentBlock.value === 0) {
        const idx = firstImageBlock.value
        currentBlock.value = idx >= 0 ? idx : 0
      }
    },
    { once: true },
  )

  const imageIndex = ref(0)
  const activeHeadingId = ref<string | null>(null)

  // 相册浮层显隐：默认展示，用户可收起看完整地图
  const showPhotos = ref(true)

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
  const intro = computed(() => renderMarkdown(introContent(), 'intro-'))

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

  const hasBody = computed(() =>
    Boolean(intro.value.html) || renderedBlocks.value.some((block) => block.title || block.html),
  )

  return {
    // 核心 computed
    blocks,
    tripBlocks,
    mapSegments,
    hasMap,
    hasImages,
    hasVisual,
    activeImages,
    renderedBlocks,
    toc,
    hasBody,
    activeBlockTitle,
    imageCount,
    intro,

    // state
    currentBlock,
    imageIndex,
    activeHeadingId,
    showPhotos,
    viewer,
    mapRef,

    // methods
    selectBlock,
  }
}
