import request from '@/utils/request'
import type { LoginResult, ProfileResult, UserInfo } from '@/types'

export function login(data: { email: string; password: string }) {
  return request.post<never, LoginResult>('/auth/login', data)
}

export function logout() {
  return request.delete<never, { message: string }>('/auth/logout')
}

export function getMe() {
  return request.get<never, ProfileResult>('/auth/me')
}

export function updateProfile(data: { name?: string; email?: string }) {
  return request.patch<never, UserInfo>('/profile', data)
}

/** 上传头像（multipart），返回更新后的当前用户 */
export function uploadAvatar(file: File) {
  const form = new FormData()
  form.append('file', file)
  return request.post<never, UserInfo>('/profile/avatar', form, {
    headers: { 'Content-Type': 'multipart/form-data' }
  })
}

/** 删除头像 */
export function removeAvatar() {
  return request.delete<never, UserInfo>('/profile/avatar')
}

export function updatePassword(data: {
  current_password: string
  password: string
  password_confirmation: string
}) {
  return request.patch<never, { message: string }>('/profile/password', data)
}
