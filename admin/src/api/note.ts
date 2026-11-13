import request from '@/utils/request'
import type { AdminNote, AdminNoteListResult, NotePayload, ReviewRecord } from '@/types'

export interface NoteQuery {
  page?: number
  per_page?: number
  keyword?: string
  channel?: string
  status?: string
}

/** 后台内容列表（走 /api/v1/admin/notes，需要 content:note:list 权限） */
export function fetchNotes(params: NoteQuery) {
  return request.get<never, AdminNoteListResult>('/admin/notes', { params })
}

export function createNote(data: NotePayload) {
  return request.post<never, AdminNote>('/admin/notes', data)
}

export function updateNote(id: number, data: Partial<NotePayload>) {
  return request.patch<never, AdminNote>(`/admin/notes/${id}`, data)
}

export function deleteNote(id: number) {
  return request.delete<never, { message: string }>(`/admin/notes/${id}`)
}

/** 上传详情页图片，返回可访问地址 */
export function uploadNoteImage(file: File) {
  const form = new FormData()
  form.append('file', file)
  return request.post<never, { url: string }>('/admin/note_images', form)
}

/** 提交审核：草稿/驳回 → 待审 */
export function submitNote(id: number) {
  return request.post<never, AdminNote>(`/admin/notes/${id}/submit`)
}

/** 作者撤回：待审 → 草稿 */
export function withdrawNote(id: number) {
  return request.post<never, AdminNote>(`/admin/notes/${id}/withdraw`)
}

/** 查看审核历史（审核视角可看全部，作者只能看自己的） */
export function fetchNoteReviews(id: number) {
  return request.get<never, { items: ReviewRecord[] }>(`/admin/notes/${id}/reviews`)
}
