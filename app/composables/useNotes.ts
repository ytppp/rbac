import type { Ref } from 'vue'
import { computed, ref, watch } from 'vue'

export interface Note {
  id: number
  title: string
  cover: string
  /** 封面宽高比（宽 / 高），图片加载前用它占位，避免瀑布流抖动 */
  cover_ratio: number
  author: string
  avatar_color: string
  likes: number
  channel: string
  /** 当前登录用户是否已点赞（未登录恒为 false） */
  liked: boolean
}

export interface PageMeta {
  page: number
  per_page: number
  total: number
  total_pages: number
}

export interface NoteListResult {
  items: Note[]
  channels: string[]
  meta: PageMeta
}

/**
 * 每页条数：必须明显小于总条数，否则只有一页、无限下拉永远触发不了。
 * 取 12 既能保证首屏足够高（哨兵不在首屏可视区内，需要滚动才加载下一页），
 * 又能让现有内容分成多页。
 */
const PER_PAGE = 12

/**
 * 内容列表：支持「无限下拉」。
 *
 * 用法上和原来的 useNotes 很像，但多返回了 hasMore / loadMore：
 *   - 首次进入加载第 1 页（SSR 时就会跑，首屏直接带内容）
 *   - 频道或搜索词变化时，清空列表重新从第 1 页开始
 *   - 页面滚到底时调用 loadMore()，把下一页追加到列表末尾
 *
 * 之所以不用 useAsyncData，是因为它适合「一次取一份数据」，
 * 而无限滚动需要把多页结果累积到同一个数组里，用普通 ref 更直观。
 */
export async function useNotesFeed(channel: Ref<string>, keyword: Ref<string>) {
  const { authHeaders } = useAuth()

  const notes = ref<Note[]>([])
  const channels = ref<string[]>([])
  const meta = ref<PageMeta | null>(null)
  const pending = ref(false)
  const error = ref(false)

  // 还有没有下一页：当前页 < 总页数
  const hasMore = computed(() => !!meta.value && meta.value.page < meta.value.total_pages)

  async function fetchPage(page: number) {
    const baseURL = useApiBase()
    pending.value = true
    error.value = false

    try {
      const result = await $fetch<NoteListResult>('/notes', {
        baseURL,
        query: {
          channel: channel.value,
          keyword: keyword.value.trim() || undefined,
          page,
          per_page: PER_PAGE
        },
        // 带上 token，后端就会把每条内容的 liked 状态一并算好返回
        headers: authHeaders()
      })

      channels.value = result.channels
      meta.value = result.meta
      // 第 1 页是「替换」，之后的页是「追加」
      notes.value = page === 1 ? result.items : notes.value.concat(result.items)
    } catch {
      error.value = true
    } finally {
      pending.value = false
    }
  }

  /** 加载下一页（滚到底时由页面调用） */
  async function loadMore() {
    if (pending.value || !hasMore.value) return

    await fetchPage((meta.value?.page ?? 0) + 1)
  }

  // 首次加载
  await fetchPage(1)

  // 筛选条件变化 -> 重置并重新加载第一页
  watch([channel, keyword], () => {
    meta.value = null
    notes.value = []
    fetchPage(1)
  })

  return { notes, channels, meta, pending, error, hasMore, loadMore }
}
