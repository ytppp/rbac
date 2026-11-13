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
  access_token: string
  refresh_token: string
  expires_in: number
  user: UserInfo
  roles: string[]
  permissions: string[]
}

export type NoteSectionType = 'plane' | 'driving' | 'walking' | 'none'

export interface NoteSectionPoint {
  lng?: number
  lat?: number
  name?: string
}

/** 详情页的一段内容：标题 + Markdown 正文 + 可选行程 + 图片，整段自成一个块 */
export interface NoteSection {
  title?: string
  content?: string
  type?: NoteSectionType
  origin?: NoteSectionPoint
  destination?: NoteSectionPoint
  /** 预计耗时（秒） */
  duration?: number
  completed?: boolean
  images?: string[]
}

/** 内容状态：草稿 / 待审 / 已发布 / 已下架 / 已驳回 */
export type NoteStatus = 'draft' | 'pending' | 'published' | 'archived' | 'rejected'

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
  status: NoteStatus
  /** 标签名列表 */
  tags?: string[]
  content: string
  sections: NoteSection[]
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
  content: string
  sections: NoteSection[]
  /** 标签名列表：已有标签复用，新名字由后端自动创建 */
  tags?: string[]
  /** 内容状态，不传时后端按角色给默认值 */
  status?: NoteStatus
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

/** 审核流水条目（时间线上的一条记录） */
export interface ReviewRecord {
  id: number
  action: 'submit' | 'approve' | 'reject' | 'withdraw' | 'auto_pending' | 'archive' | 'restore' | 'force_publish'
  from_status: NoteStatus | null
  to_status: NoteStatus | null
  reason: string | null
  /** 审核人脱敏后的显示名（作者侧看是 "审核员 N"，审核侧看是真实姓名或 "系统"） */
  reviewer_display: string
  created_at: string
}

/** 审核队列接口里一条待审核/已审核的内容摘要 */
export interface ReviewQueueItem {
  id: number
  title: string
  cover_url: string
  author_name: string
  user_id: number
  channel: string
  status: NoteStatus
  created_at: string
  /** 进入当前状态的时间（最近一次流水的 created_at） */
  pending_since?: string
  /** 最近一次流水的动作类型 */
  last_action?: ReviewRecord['action']
  /** 最近一次的驳回原因 */
  last_reason?: string
}

export interface ReviewQueueListResult {
  items: ReviewQueueItem[]
  channels: string[]
  meta: PageMeta
}
