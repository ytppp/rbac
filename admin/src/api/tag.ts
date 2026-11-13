import request from '@/utils/request'

export interface AdminTag {
  id: number
  name: string
  notes_count: number
  sort: number
  created_at: string
}

export interface TagListResult {
  items: AdminTag[]
  meta: {
    page: number
    per_page: number
    total: number
    total_pages: number
  }
}

export interface TagQuery {
  page?: number
  per_page?: number
  keyword?: string
}

/** 标签列表（需要 content:tag:list 权限） */
export function fetchTags(params: TagQuery) {
  return request.get<never, TagListResult>('/admin/tags', { params })
}

export function createTag(data: { name: string, sort?: number }) {
  return request.post<never, AdminTag>('/admin/tags', data)
}

export function updateTag(id: number, data: { name?: string, sort?: number }) {
  return request.patch<never, AdminTag>(`/admin/tags/${id}`, data)
}

export function deleteTag(id: number) {
  return request.delete<never, { message: string }>(`/admin/tags/${id}`)
}
