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
  /** 头像地址，未上传时为 null */
  avatar_url: string | null
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

/** 管理后台看到的内容（字段用数据库列名，便于编辑弹窗原样回填） */
export interface AdminNote {
  id: number
  title: string
  cover_url: string
  cover_ratio: number
  author_name: string
  avatar_color: string
  likes_count: number
  channel: string
  sort: number
  created_at: string
  updated_at: string
}

/** 新增 / 编辑内容时提交的字段（作者由当前登录用户决定，不在提交字段里） */
export interface NotePayload {
  title: string
  cover_url: string
  cover_ratio: number
  avatar_color: string
  channel: string
  sort: number
}

/** 内容列表接口的返回：比通用 PageResult 多一个频道列表 */
export interface AdminNoteListResult {
  items: AdminNote[]
  channels: string[]
  meta: PageMeta
}

export interface ProfileResult {
  user: UserInfo
  roles: string[]
  permissions: string[]
}
