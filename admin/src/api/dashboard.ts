import request from '@/utils/request'

export interface DashboardStats {
  notes: {
    total: number
    published: number
    pending: number
    draft: number
    archived: number
  }
  users: {
    total: number
    new_this_week: number
  }
  likes: number
  comments: number
  favorites: number
  pending_reports: number
  trend: Array<{ date: string, notes: number, likes: number }>
}

/** 首页数据看板 */
export function fetchDashboardStats() {
  return request.get<never, DashboardStats>('/admin/dashboard/stats')
}
