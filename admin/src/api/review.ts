import request from '@/utils/request'
import type { AdminNote, ReviewQueueListResult } from '@/types'

export interface ReviewQuery {
  page?: number
  per_page?: number
  keyword?: string
  channel?: string
  /** 默认 pending；可传 all（全部状态）、my（我处理过的） */
  scope?: 'pending' | 'all' | 'my'
  status?: string
}

/** 审核队列：默认只看待审，传 scope=all 看全部，scope=my 看自己处理过的 */
export function fetchReviewQueue(params: ReviewQuery) {
  return request.get<never, ReviewQueueListResult>('/admin/reviews', { params })
}

/** 审核通过（pending → published） */
export function approveReview(id: number) {
  return request.post<never, AdminNote>(`/admin/reviews/${id}/approve`)
}

/** 审核驳回（pending → rejected），必须带 reason */
export function rejectReview(id: number, reason: string) {
  return request.post<never, AdminNote>(`/admin/reviews/${id}/reject`, { reason })
}
