import request from '@/utils/request'
import type { AdminNote, AdminNoteListResult, NotePayload } from '@/types'

export interface NoteQuery {
  page?: number
  per_page?: number
  keyword?: string
  channel?: string
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
  // 不手动指定 Content-Type，交给浏览器带上 multipart boundary
  return request.post<never, { url: string }>('/admin/note_images', form)
}
