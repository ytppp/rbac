import request from '@/utils/request'
import type { ListResult, MenuItem, Permission, PermissionOption, PermissionType } from '@/types'

export interface PermissionQuery {
  keyword?: string
  type?: PermissionType
  status?: number
  flat?: boolean
}

export interface PermissionPayload {
  name: string
  code: string
  type: PermissionType
  parent_id: number | null
  path?: string | null
  component?: string | null
  icon?: string | null
  sort: number
  status: number
}

/** 权限列表：默认返回树，flat=true 返回扁平列表 */
export function fetchPermissions(params: PermissionQuery = {}) {
  return request.get<never, ListResult<Permission>>('/permissions', { params })
}

export function fetchPermissionOptions() {
  return request.get<never, ListResult<PermissionOption>>('/permissions/options')
}

export function createPermission(data: PermissionPayload) {
  return request.post<never, Permission>('/permissions', data)
}

export function updatePermission(id: number, data: Partial<PermissionPayload>) {
  return request.patch<never, Permission>(`/permissions/${id}`, data)
}

export function deletePermission(id: number) {
  return request.delete<never, { message: string }>(`/permissions/${id}`)
}

/** 当前登录用户可访问的菜单树 */
export function fetchMenus() {
  return request.get<never, ListResult<MenuItem>>('/menus')
}
