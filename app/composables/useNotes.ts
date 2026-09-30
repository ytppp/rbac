import type { Ref } from 'vue'

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
}

export interface NoteListResult {
  items: Note[]
  channels: string[]
  meta: {
    page: number
    per_page: number
    total: number
    total_pages: number
  }
}

/**
 * 内容列表来自 api 服务的公开接口 GET /api/v1/notes，
 * 频道和关键词都交给后端过滤，前端只负责传参。
 */
export function useNotes(channel: Ref<string>, keyword: Ref<string>) {
  const baseURL = useApiBase()

  const query = computed(() => ({
    channel: channel.value,
    keyword: keyword.value.trim() || undefined,
    per_page: 50
  }))

  return useAsyncData(
    'notes',
    () => $fetch<NoteListResult>('/notes', { baseURL, query: query.value }),
    { watch: [query] }
  )
}
