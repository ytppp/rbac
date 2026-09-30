import request from '@/utils/request'
import type { ListResult, PageResult, Role, RoleOption } from '@/types'

export interface RoleQuery {
  page?: number
  per_page?: number
  keyword?: string
  status?: number
}

export interface RolePayload {
  name: string
  code: string
  description?: string
  status: number
  permission_ids?: number[]
}

export function fetchRoles(params: RoleQuery) {
  return request.get<never, PageResult<Role>>('/roles', { params })
}

export function fetchRoleOptions() {
  return request.get<never, ListResult<RoleOption>>('/roles/options')
}

export function fetchRole(id: number) {
  return request.get<never, Role>(`/roles/${id}`)
}

export function createRole(data: RolePayload) {
  return request.post<never, Role>('/roles', data)
}

export function updateRole(id: number, data: Partial<RolePayload>) {
  return request.patch<never, Role>(`/roles/${id}`, data)
}

export function deleteRole(id: number) {
  return request.delete<never, { message: string }>(`/roles/${id}`)
}
