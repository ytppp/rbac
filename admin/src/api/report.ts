import request from '@/utils/request'

export interface AdminReport {
  id: number
  reason: string
  detail: string | null
  status: 'pending' | 'resolved' | 'ignored'
  created_at: string
  handled_at: string | null
  reporter: { id: number, name: string }
  /** 举报内容时的目标；举报评论时为空 */
  note: { id: number, title: string, status: string } | null
  /** 举报评论时的目标；举报内容时为空 */
  comment: { id: number, content: string, note_title: string | null } | null
}

export interface ReportListResult {
  items: AdminReport[]
  meta: {
    page: number
    per_page: number
    total: number
    total_pages: number
  }
}

/** 举报列表（需要 content:report:list 权限） */
export function fetchReports(params: { page?: number, per_page?: number, status?: string }) {
  return request.get<never, ReportListResult>('/admin/reports', { params })
}

/** 处理举报：可同时下架内容或删除被举报的评论 */
export function handleReport(
  id: number,
  data: { status: 'resolved' | 'ignored', archive_note?: boolean, delete_comment?: boolean }
) {
  return request.patch<never, AdminReport>(`/admin/reports/${id}`, data)
}
