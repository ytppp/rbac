import request from '@/utils/request'
import type { PageResult, UserInfo } from '@/types'

export interface UserQuery {
  page?: number
  per_page?: number
  keyword?: string
  status?: number
  role_id?: number
}

export interface UserPayload {
  email: string
  name: string
  password?: string
  password_confirmation?: string
  status: number
  role_ids: number[]
}

export function fetchUsers(params: UserQuery) {
  return request.get<never, PageResult<UserInfo>>('/users', { params })
}

export function fetchUser(id: number) {
  return request.get<never, UserInfo>(`/users/${id}`)
}

export function createUser(data: UserPayload) {
  return request.post<never, UserInfo>('/users', data)
}

export function updateUser(id: number, data: Partial<UserPayload>) {
  return request.patch<never, UserInfo>(`/users/${id}`, data)
}

export function deleteUser(id: number) {
  return request.delete<never, { message: string }>(`/users/${id}`)
}

export function updateUserStatus(id: number, status: number) {
  return request.patch<never, UserInfo>(`/users/${id}/status`, { status })
}

export function resetUserPassword(id: number, data: { password: string; password_confirmation: string }) {
  return request.patch<never, { message: string }>(`/users/${id}/password`, data)
}
