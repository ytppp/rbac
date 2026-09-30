export interface PageMeta {
  page: number
  per_page: number
  total: number
  total_pages: number
}

export interface PageResult<T> {
  items: T[]
  meta: PageMeta
}

export interface ListResult<T> {
  items: T[]
}

export interface RoleBrief {
  id: number
  name: string
  code: string
}

export interface UserInfo {
  id: number
  email: string
  name: string
  status: number
  status_text: string
  last_login_at: string | null
  created_at: string
  updated_at: string
  roles?: RoleBrief[]
  role_ids?: number[]
}

export interface Role {
  id: number
  name: string
  code: string
  description: string | null
  status: number
  status_text: string
  built_in: boolean
  super_admin: boolean
  user_count: number
  permission_ids?: number[]
  created_at: string
  updated_at: string
}

export interface RoleOption {
  id: number
  name: string
  code: string
  status: number
}

/** 0=菜单 1=按钮 */
export type PermissionType = 0 | 1

export interface Permission {
  id: number
  name: string
  code: string
  type: PermissionType
  parent_id: number | null
  path: string | null
  component: string | null
  icon: string | null
  sort: number
  status: number
  type_text?: string
  status_text?: string
  created_at?: string
  updated_at?: string
  children?: Permission[]
}

export interface PermissionOption {
  id: number
  name: string
  code: string
  type: PermissionType
  parent_id: number | null
}

export interface MenuItem {
  id: number
  name: string
  code: string
  path: string
  component: string | null
  icon: string | null
  sort: number
  children: MenuItem[]
}

export interface LoginResult {
  token: string
  expires_in: number
  user: UserInfo
  roles: string[]
  permissions: string[]
}

export interface ProfileResult {
  user: UserInfo
  roles: string[]
  permissions: string[]
}
