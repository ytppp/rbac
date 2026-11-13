<template>
  <div class="page-container">
    <div class="page-card">
      <div class="table-toolbar">
        <el-input
          v-model="query.keyword"
          placeholder="搜索标题 / 作者 / 频道"
          clearable
          style="width: 220px"
          @keyup.enter="handleSearch"
        />
        <el-select v-model="query.channel" placeholder="全部频道" clearable style="width: 150px">
          <el-option v-for="item in channels" :key="item" :label="item" :value="item" />
        </el-select>
        <el-select v-model="query.status" placeholder="全部状态" clearable style="width: 130px">
          <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
        </el-select>
        <el-button type="primary" :icon="Search" @click="handleSearch">查询</el-button>
        <el-button :icon="Refresh" @click="handleReset">重置</el-button>

        <div class="spacer" />

        <span class="page-hint">
          {{ hasReviewPrivilege ? '全部内容' : '仅显示我发布的内容' }}
        </span>
        <el-button v-perm="'content:note:create'" type="primary" :icon="Plus" @click="openCreate">
          新增内容
        </el-button>
      </div>

      <el-table v-loading="loading" :data="list" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="封面" width="90">
          <template #default="{ row }">
            <el-image
              class="cover-thumb"
              :src="row.cover_url"
              fit="cover"
              :preview-src-list="[row.cover_url]"
              preview-teleported
            />
          </template>
        </el-table-column>
        <el-table-column prop="title" label="标题" min-width="220" show-overflow-tooltip />
        <el-table-column label="详情" width="110">
          <template #default="{ row }">
            <el-tag v-if="row.sections?.length" size="small" type="info">{{ row.sections.length }} 段</el-tag>
            <span v-else class="muted">纯图文</span>
          </template>
        </el-table-column>
        <el-table-column prop="author_name" label="作者" width="120" />
        <el-table-column prop="channel" label="频道" width="100" />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="statusType(row.status)">{{ statusLabel(row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="likes_count" label="点赞数" width="90" />
        <el-table-column prop="sort" label="排序" width="80" />
        <el-table-column label="创建时间" width="170">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="280" fixed="right">
          <template #default="{ row }">
            <!-- 作者在草稿/驳回态能提交，审核视角手动提交也可以 -->
            <el-button
              v-if="canSubmit(row)"
              v-perm="'content:note:submit'"
              link
              type="primary"
              @click="handleSubmit(row)"
            >
              提交审核
            </el-button>
            <!-- 作者撤回待审内容 -->
            <el-button
              v-if="canWithdraw(row)"
              v-perm="'content:note:withdraw'"
              link
              type="warning"
              @click="handleWithdraw(row)"
            >
              撤回
            </el-button>
            <!-- 编辑：草稿/驳回态作者可编，已发布/已下架只有审核视角能 -->
            <el-button
              v-if="canEdit(row)"
              v-perm="'content:note:update'"
              link
              type="primary"
              @click="openEdit(row)"
            >
              编辑
            </el-button>
            <el-button
              v-perm="'content:note:delete'"
              link
              type="danger"
              :disabled="!canDelete(row)"
              @click="handleDelete(row)"
            >
              删除
            </el-button>
            <el-button v-perm="'content:review:history'" link type="info" @click="openReviewHistory(row)">
              审核历史
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-wrapper">
        <el-pagination
          v-model:current-page="query.page"
          v-model:page-size="query.per_page"
          :total="total"
          :page-sizes="[10, 20, 50]"
          layout="total, sizes, prev, pager, next"
          @current-change="loadList"
          @size-change="handleSearch"
        />
      </div>
    </div>

    <!-- 新增 / 编辑 -->
    <el-dialog
      v-model="dialogVisible"
      :title="isCreate ? '新增内容' : '编辑内容'"
      width="900px"
      top="6vh"
      @closed="resetForm"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="标题" prop="title">
          <el-input v-model="form.title" placeholder="请输入标题" maxlength="100" show-word-limit />
        </el-form-item>

        <el-form-item label="频道" prop="channel">
          <el-select
            v-model="form.channel"
            placeholder="选择或输入新频道"
            filterable
            allow-create
            default-first-option
            style="width: 240px"
          >
            <el-option v-for="item in channelOptions" :key="item" :label="item" :value="item" />
          </el-select>
        </el-form-item>

        <el-form-item label="状态">
          <el-select v-model="form.status" style="width: 200px" :disabled="!hasReviewPrivilege">
            <el-option v-for="item in statusOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
          <span class="hint block">
            {{ hasReviewPrivilege ? '审核视角可直接指定状态' : '作者提交后进入待审，通过后自动发布' }}
          </span>
        </el-form-item>

        <el-form-item label="标签">
          <el-select
            v-model="form.tags"
            multiple
            filterable
            allow-create
            default-first-option
            :reserve-keyword="false"
            placeholder="选择已有标签，或输入新标签后回车"
            style="width: 420px"
          >
            <el-option v-for="item in tagOptions" :key="item.id" :label="item.name" :value="item.name" />
          </el-select>
          <span class="hint block">最多 10 个；直接输入新名称回车即可创建</span>
        </el-form-item>

        <el-form-item label="开篇正文">
          <el-input
            v-model="form.content"
            type="textarea"
            :rows="4"
            placeholder="可选：不绑定任何行程段的开场白 / 结尾，Markdown 格式"
          />
          <span class="hint block">开篇正文不绑定行程；正文章节请写进下面每一段的「段正文」</span>
        </el-form-item>

        <!-- 有上传图片时，从图片里选一张作为列表封面；没有图片时走原来的封面逻辑 -->
        <el-form-item v-if="uploadedImages.length" label="列表封面">
          <div class="cover-picker">
            <div
              v-for="item in uploadedImages"
              :key="item.url"
              class="cover-option"
              :class="{ 'is-active': form.cover_url === item.url }"
              @click="selectCover(item.url)"
            >
              <img :src="item.url" :alt="`第 ${item.section} 段图片`" />
              <span class="cover-option__tag">{{ form.cover_url === item.url ? '当前封面' : '设为封面' }}</span>
            </div>
          </div>
          <span class="hint block">点击图片设为社区列表封面</span>
        </el-form-item>

        <template v-else>
          <el-form-item label="封面地址" prop="cover_url">
            <el-input v-model="form.cover_url" placeholder="图片直链，或下方用提示词生成" />
          </el-form-item>

          <el-form-item label="提示词生成">
            <div class="gen-row">
              <el-input v-model="genPrompt" placeholder="英文提示词，如 sunny beach..." />
              <el-select v-model="genSize" style="width: 150px">
                <el-option v-for="size in COVER_SIZES" :key="size" :label="size" :value="size" />
              </el-select>
              <el-button @click="generateCover">生成</el-button>
            </div>
          </el-form-item>

          <el-form-item label="宽高比" prop="cover_ratio">
            <el-input-number
              v-model="form.cover_ratio"
              :min="0.01"
              :max="99"
              :step="0.01"
              :precision="4"
            />
            <span class="hint">封面宽 / 高，图片加载前用它占位</span>
          </el-form-item>
        </template>

        <el-divider content-position="left">行程与图片分段</el-divider>
        <p class="section-tip">
          每段 = 标题 + Markdown 正文 + 行程 + 图片，段的顺序就是详情页展示顺序；点详情页的段标题会同时切换该段图片并聚焦该段地图路线。
        </p>

        <div v-for="(section, index) in form.sections" :key="index" class="section-card">
          <div class="section-head">
            <span class="section-title">第 {{ index + 1 }} 段</span>
            <div>
              <el-button link :disabled="index === 0" @click="moveSection(index, -1)">上移</el-button>
              <el-button
                link
                :disabled="index === form.sections.length - 1"
                @click="moveSection(index, 1)"
              >
                下移
              </el-button>
              <el-button link type="danger" @click="removeSection(index)">删除</el-button>
            </div>
          </div>

          <el-form-item label="段标题">
            <el-input
              v-model="section.title"
              placeholder="如：第一段 · 飞往上海（留空则不显示标题）"
              maxlength="60"
              show-word-limit
            />
          </el-form-item>

          <el-form-item label="段正文">
            <el-input
              v-model="section.content"
              type="textarea"
              :rows="4"
              placeholder="这一段要展示的 Markdown 内容"
            />
          </el-form-item>

          <el-form-item label="交通方式">
            <el-select v-model="section.type" style="width: 170px">
              <el-option label="仅图片（无地图）" value="none" />
              <el-option label="飞机" value="plane" />
              <el-option label="驾车" value="driving" />
              <el-option label="步行" value="walking" />
            </el-select>
            <el-checkbox v-if="section.type !== 'none'" v-model="section.completed" class="section-check">
              该段已完成
            </el-checkbox>
          </el-form-item>

          <template v-if="section.type !== 'none'">
            <el-form-item label="起点">
              <LocationPicker v-model="section.origin" />
            </el-form-item>

            <el-form-item label="终点">
              <LocationPicker v-model="section.destination" />
            </el-form-item>

            <el-form-item label="预计耗时">
              <el-input-number v-model="section.duration" :min="0" :step="5" />
              <span class="hint">分钟，留空则不展示</span>
            </el-form-item>
          </template>

          <el-form-item label="该段图片">
            <div class="upload-block">
              <el-upload
                :show-file-list="false"
                :multiple="true"
                accept="image/png,image/jpeg,image/webp"
                :before-upload="beforeUpload(section)"
              >
                <el-button :icon="Upload" :loading="uploadingCount > 0">上传图片</el-button>
              </el-upload>
              <span class="hint">支持 PNG / JPEG / WebP，超过 1.5MB 会自动压缩，单张不超过 5MB</span>

              <div v-if="section.images.length" class="thumb-grid">
                <div v-for="(url, imageIndex) in section.images" :key="`${url}-${imageIndex}`" class="thumb">
                  <img :src="url" alt="分段图片" />
                  <span class="thumb__del" @click="removeImage(section, imageIndex)">
                    <el-icon><Close /></el-icon>
                  </span>
                </div>
              </div>
            </div>
          </el-form-item>
        </div>

        <el-form-item>
          <el-button :icon="Plus" @click="addSection">新增一段</el-button>
        </el-form-item>

        <el-form-item label="作者">
          <span class="author-text">{{ form.author_name || currentUserName }}</span>
          <span class="hint">
            {{ hasOwnAvatar ? '你已设置头像，后台与社区将显示你的头像' : '作者由当前登录用户决定，不可修改' }}
          </span>
        </el-form-item>

        <el-form-item v-if="!hasOwnAvatar" label="头像颜色" prop="avatar_color">
          <el-color-picker v-model="form.avatar_color" />
          <span class="hint">作者无头像时，用它作为首字圆圈的底色</span>
        </el-form-item>

        <el-form-item label="排序" prop="sort">
          <el-input-number v-model="form.sort" :min="0" />
          <span class="hint">数值越小越靠前</span>
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="handleSubmitForm">确定</el-button>
      </template>
    </el-dialog>

    <!-- 审核历史弹层 -->
    <el-dialog
      v-model="reviewDialog.visible"
      :title="reviewDialog.title || '审核历史'"
      width="620px"
      top="8vh"
    >
      <el-timeline v-loading="reviewDialog.loading">
        <el-timeline-item
          v-for="(item, index) in reviewDialog.items"
          :key="item.id || index"
          :timestamp="formatTime(item.created_at)"
          placement="top"
          :type="reviewItemType(item)"
        >
          <div class="review-timeline-main">
            <el-tag :type="reviewItemTagType(item)" size="small">
              {{ reviewActionLabel(item.action) }}
            </el-tag>
            <span class="review-status-change" v-if="item.from_status || item.to_status">
              {{ item.from_status ? statusLabel(item.from_status) : '—' }}
              <el-icon class="change-arrow"><ArrowRight /></el-icon>
              {{ item.to_status ? statusLabel(item.to_status) : '—' }}
            </span>
          </div>
          <div class="review-timeline-sub">
            <span class="reviewer">{{ item.reviewer_display }}</span>
            <span v-if="item.reason" class="reason">「{{ item.reason }}」</span>
          </div>
        </el-timeline-item>
      </el-timeline>
      <el-empty v-if="!reviewDialog.loading && !reviewDialog.items.length" description="暂无审核记录" />
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import { ArrowRight, Close, Plus, Refresh, Search, Upload } from '@element-plus/icons-vue'
import {
  createNote,
  deleteNote,
  fetchNoteReviews,
  fetchNotes,
  submitNote,
  updateNote,
  uploadNoteImage,
  withdrawNote
} from '@/api/note'
import { fetchTags, type AdminTag } from '@/api/tag'
import LocationPicker from '@/components/LocationPicker.vue'
import { useUserStore } from '@/stores/user'
import { formatTime } from '@/utils/format'
import { compressImage } from '@/utils/image'
import type {
  AdminNote,
  NotePayload,
  NoteSection,
  NoteSectionPoint,
  NoteSectionType,
  NoteStatus,
  ReviewRecord
} from '@/types'

const userStore = useUserStore()

// 是否拥有审核视角：能看全部内容、绕过状态机、审核等
const hasReviewPrivilege = computed(() =>
  userStore.isSuperAdmin || userStore.hasPermission('content:review:list')
)
const currentUserName = computed(() => userStore.displayName)
const hasOwnAvatar = computed(() => Boolean(userStore.userInfo?.avatar_url))

// 文生图服务地址，和 seed 里用的是同一个
const IMAGE_API_BASE = 'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image'
const COVER_SIZES = ['square_hd', 'square', 'portrait_4_3', 'portrait_16_9', 'landscape_4_3', 'landscape_16_9']
const SIZE_RATIOS: Record<string, number> = {
  square_hd: 1,
  square: 1,
  portrait_4_3: 0.75,
  portrait_16_9: 0.5625,
  landscape_4_3: 1.3333,
  landscape_16_9: 1.7778
}
const ALL_CHANNEL = '推荐'

interface SectionForm {
  title: string
  content: string
  type: NoteSectionType
  origin: NoteSectionPoint
  destination: NoteSectionPoint
  duration?: number
  completed: boolean
  images: string[]
}

function createSection(): SectionForm {
  return {
    title: '',
    content: '',
    type: 'none',
    origin: { name: '', lng: undefined, lat: undefined },
    destination: { name: '', lng: undefined, lat: undefined },
    duration: undefined,
    completed: false,
    images: []
  }
}

const loading = ref(false)
const submitting = ref(false)
const uploadingCount = ref(0)
const dialogVisible = ref(false)
const isCreate = ref(true)
const list = ref<AdminNote[]>([])
const total = ref(0)
const channels = ref<string[]>([])
const tagOptions = ref<AdminTag[]>([])

// 审核历史弹层
const reviewDialog = reactive<{
  visible: boolean
  loading: boolean
  title: string
  items: ReviewRecord[]
}>({
  visible: false,
  loading: false,
  title: '',
  items: []
})

const query = reactive({
  page: 1,
  per_page: 10,
  keyword: '',
  channel: undefined as string | undefined,
  status: undefined as NoteStatus | undefined
})

// 状态多了「已驳回」
const statusOptions: { label: string; value: NoteStatus }[] = [
  { label: '草稿', value: 'draft' },
  { label: '待审', value: 'pending' },
  { label: '已发布', value: 'published' },
  { label: '已下架', value: 'archived' },
  { label: '已驳回', value: 'rejected' }
]

const STATUS_MAP: Record<NoteStatus, { label: string; type: 'info' | 'warning' | 'success' | 'danger' }> = {
  draft: { label: '草稿', type: 'info' },
  pending: { label: '待审', type: 'warning' },
  published: { label: '已发布', type: 'success' },
  archived: { label: '已下架', type: 'danger' },
  rejected: { label: '已驳回', type: 'danger' }
}

function statusLabel(status?: NoteStatus | null) {
  if (!status) return '—'
  return STATUS_MAP[status]?.label ?? status
}
function statusType(status?: NoteStatus | null) {
  if (!status) return 'info'
  return STATUS_MAP[status]?.type ?? 'info'
}

// 审核时间线的辅助
const REVIEW_ACTION_LABELS: Record<string, string> = {
  submit: '提交审核',
  approve: '审核通过',
  reject: '审核驳回',
  withdraw: '作者撤回',
  auto_pending: '内容已更新，自动重新审核',
  archive: '强制下架',
  restore: '重新发布',
  force_publish: '管理员强制发布'
}
function reviewActionLabel(action: string) {
  return REVIEW_ACTION_LABELS[action] ?? action
}
function reviewItemType(item: ReviewRecord) {
  if (item.action === 'reject' || item.action === 'archive') return 'danger'
  if (item.action === 'approve' || item.action === 'restore' || item.action === 'force_publish') return 'success'
  if (item.action === 'auto_pending') return 'warning'
  return 'primary'
}
function reviewItemTagType(item: ReviewRecord) {
  if (item.action === 'reject' || item.action === 'archive') return 'danger'
  if (item.action === 'approve' || item.action === 'restore' || item.action === 'force_publish') return 'success'
  return 'warning'
}

// 按钮显隐
const EDITABLE_STATUSES: NoteStatus[] = ['draft', 'rejected']
function canEdit(row: AdminNote) {
  if (hasReviewPrivilege.value) return true
  return EDITABLE_STATUSES.includes(row.status)
}
function canSubmit(row: AdminNote) {
  // 作者或审核视角都可以提交；后端会校验归属
  return ['draft', 'rejected'].includes(row.status)
}
function canWithdraw(row: AdminNote) {
  return row.status === 'pending'
}
function canDelete(row: AdminNote) {
  // 作者不能删处罚状态的 archived；审核视角可以
  if (hasReviewPrivilege.value) return true
  return row.status !== 'archived'
}

const formRef = ref<FormInstance>()
const form = reactive({
  id: 0,
  title: '',
  cover_url: '',
  cover_ratio: 1,
  author_name: '',
  avatar_color: '#ff6b6b',
  channel: '',
  sort: 0,
  content: '',
  status: 'draft' as NoteStatus,
  tags: [] as string[],
  sections: [createSection()] as SectionForm[]
})

const genPrompt = ref('')
const genSize = ref(COVER_SIZES[0])

const channelOptions = computed(() => channels.value.filter((item) => item !== ALL_CHANNEL))

const rules: FormRules = {
  title: [{ required: true, message: '请输入标题', trigger: 'blur' }],
  cover_url: [{ required: true, message: '请上传图片并选择封面，或填写封面地址', trigger: 'blur' }],
  channel: [{ required: true, message: '请选择或输入频道', trigger: 'change' }],
  cover_ratio: [{ required: true, message: '请输入宽高比', trigger: 'blur' }],
  avatar_color: [
    { required: true, message: '请选择头像颜色', trigger: 'change' },
    { pattern: /^#[0-9a-fA-F]{6}$/, message: '必须是 #RRGGBB 格式', trigger: 'change' }
  ]
}

const uploadedImages = computed(() =>
  form.sections.flatMap((section, index) =>
    section.images.map((url) => ({ url, section: index + 1 }))
  )
)

async function loadList() {
  loading.value = true
  try {
    const result = await fetchNotes({
      page: query.page,
      per_page: query.per_page,
      keyword: query.keyword || undefined,
      channel: query.channel,
      status: query.status
    })
    list.value = result.items
    channels.value = result.channels
    total.value = result.meta.total
  } finally {
    loading.value = false
  }
}

function handleSearch() {
  query.page = 1
  loadList()
}

function handleReset() {
  query.keyword = ''
  query.channel = undefined
  query.status = undefined
  handleSearch()
}

function resetForm() {
  formRef.value?.resetFields()
  form.id = 0
  form.title = ''
  form.cover_url = ''
  form.cover_ratio = 1
  form.author_name = ''
  form.avatar_color = '#ff6b6b'
  form.channel = ''
  form.sort = 0
  form.content = ''
  form.status = 'draft'
  form.tags = []
  form.sections = [createSection()]
  genPrompt.value = ''
  genSize.value = COVER_SIZES[0]
}

function openCreate() {
  isCreate.value = true
  form.sections = [createSection()]
  // 新建一律草稿，后端也会强制覆盖
  form.status = 'draft'
  dialogVisible.value = true
}

function toSectionForm(section: NoteSection): SectionForm {
  return {
    title: section.title ?? '',
    content: section.content ?? '',
    type: section.type && section.type !== 'none' ? section.type : 'none',
    origin: {
      name: section.origin?.name ?? '',
      lng: section.origin?.lng,
      lat: section.origin?.lat
    },
    destination: {
      name: section.destination?.name ?? '',
      lng: section.destination?.lng,
      lat: section.destination?.lat
    },
    duration: section.duration ? Math.round(section.duration / 60) : undefined,
    completed: Boolean(section.completed),
    images: [...(section.images ?? [])]
  }
}

async function openEdit(row: AdminNote) {
  isCreate.value = false
  dialogVisible.value = true
  form.id = row.id
  form.title = row.title
  form.cover_url = row.cover_url
  form.cover_ratio = row.cover_ratio
  form.author_name = row.author_name
  form.avatar_color = row.avatar_color
  form.channel = row.channel
  form.sort = row.sort
  form.content = row.content ?? ''
  form.status = row.status ?? 'draft'
  form.tags = [...(row.tags ?? [])]
  form.sections = (row.sections ?? []).map(toSectionForm)
  if (!form.sections.length) {
    form.sections = [createSection()]
  }

  if (uploadedImages.value.length && !uploadedImages.value.some((item) => item.url === form.cover_url)) {
    await selectCover(uploadedImages.value[0]!.url)
  }
}

function generateCover() {
  if (!genPrompt.value.trim()) {
    ElMessage.warning('请先输入提示词')
    return
  }
  form.cover_url = `${IMAGE_API_BASE}?prompt=${encodeURIComponent(genPrompt.value.trim())}&image_size=${genSize.value}`
  form.cover_ratio = SIZE_RATIOS[genSize.value] ?? 1
  ElMessage.success('已生成封面地址')
}

function loadImageRatio(url: string): Promise<number | null> {
  return new Promise((resolve) => {
    const image = new Image()
    image.onload = () => resolve(image.naturalWidth / image.naturalHeight || null)
    image.onerror = () => resolve(null)
    image.src = url
  })
}

async function selectCover(url: string) {
  form.cover_url = url
  const ratio = await loadImageRatio(url)
  if (ratio) {
    form.cover_ratio = Number(ratio.toFixed(4))
  }
}

function beforeUpload(section: SectionForm) {
  return async (file: File) => {
    if (file.size > 30 * 1024 * 1024) {
      ElMessage.warning('原图不能超过 30MB，请先压缩或裁剪')
      return false
    }
    uploadingCount.value += 1
    try {
      const compressed = await compressImage(file)
      const { url } = await uploadNoteImage(compressed)
      section.images.push(url)
      if (!form.cover_url || !uploadedImages.value.some((item) => item.url === form.cover_url)) {
        await selectCover(url)
      }
      ElMessage.success(compressed.size < file.size ? '图片已压缩并上传' : '图片上传成功')
    } catch {
      // 错误已统一处理
    } finally {
      uploadingCount.value -= 1
    }
    return false
  }
}

function removeImage(section: SectionForm, index: number) {
  const [removed] = section.images.splice(index, 1)
  if (removed && form.cover_url === removed) {
    const next = uploadedImages.value[0]?.url ?? ''
    form.cover_url = next
    if (next) {
      selectCover(next)
    }
  }
}

function addSection() {
  form.sections.push(createSection())
}
function removeSection(index: number) {
  const [removed] = form.sections.splice(index, 1)
  if (removed && removed.images.includes(form.cover_url)) {
    const next = uploadedImages.value[0]?.url ?? ''
    form.cover_url = next
    if (next) {
      selectCover(next)
    }
  }
}
function moveSection(index: number, delta: number) {
  const target = index + delta
  if (target < 0 || target >= form.sections.length) return
  const [section] = form.sections.splice(index, 1)
  if (section) form.sections.splice(target, 0, section)
}

function hasCoordinate(point: NoteSectionPoint) {
  return typeof point.lng === 'number' && Number.isFinite(point.lng) && typeof point.lat === 'number' && Number.isFinite(point.lat)
}

function buildPayload(): NotePayload {
  const sections = form.sections
    .map((section): NoteSection => {
      const images = section.images.filter(Boolean)
      const title = section.title.trim()
      const hasContent = Boolean(section.content.trim())
      const tripValid = section.type !== 'none' && hasCoordinate(section.origin) && hasCoordinate(section.destination)
      const base: NoteSection = {
        title: title || undefined,
        content: hasContent ? section.content : undefined,
        images: images.length ? images : undefined
      }
      if (!tripValid) return { ...base, type: 'none' }
      return {
        ...base,
        type: section.type,
        origin: { lng: section.origin.lng!, lat: section.origin.lat!, name: section.origin.name?.trim() || undefined },
        destination: { lng: section.destination.lng!, lat: section.destination.lat!, name: section.destination.name?.trim() || undefined },
        duration: section.duration ? Math.round(section.duration * 60) : undefined,
        completed: section.completed
      }
    })
    .filter((section) => Boolean(section.title || section.content || section.images?.length || section.type !== 'none'))

  return {
    title: form.title.trim(),
    cover_url: form.cover_url.trim(),
    cover_ratio: form.cover_ratio,
    avatar_color: form.avatar_color,
    channel: form.channel.trim(),
    sort: form.sort,
    content: form.content,
    // 只有审核视角能指定状态；后端也会再校验一次
    status: hasReviewPrivilege.value ? form.status : undefined,
    tags: form.tags,
    sections
  }
}

async function handleSubmitForm() {
  if (!formRef.value) return
  for (const [index, section] of form.sections.entries()) {
    if (section.type !== 'none' && (!hasCoordinate(section.origin) || !hasCoordinate(section.destination))) {
      ElMessage.warning(`第 ${index + 1} 段行程请选择完整的起点和终点`)
      return
    }
  }
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    if (isCreate.value) {
      await createNote(buildPayload())
      ElMessage.success('新增成功')
    } else {
      await updateNote(form.id, buildPayload())
      ElMessage.success('保存成功')
    }
    dialogVisible.value = false
    loadList()
  } catch {
    // 错误已统一处理
  } finally {
    submitting.value = false
  }
}

async function handleDelete(row: AdminNote) {
  if (!canDelete(row)) {
    ElMessage.warning(row.status === 'archived' ? '已下架的内容需要审核视角才能删除' : '当前状态下不可删除')
    return
  }
  try {
    await ElMessageBox.confirm(`确定删除内容「${row.title}」吗？`, '提示', { type: 'warning' })
  } catch {
    return
  }
  await deleteNote(row.id)
  ElMessage.success('删除成功')
  loadList()
}

async function handleSubmit(row: AdminNote) {
  try {
    await ElMessageBox.confirm(
      `确定提交内容「${row.title}」进入审核吗？审核通过后才会在社区上线。`,
      '提交审核',
      { type: 'info' }
    )
  } catch {
    return
  }
  await submitNote(row.id)
  ElMessage.success('已提交审核')
  loadList()
}

async function handleWithdraw(row: AdminNote) {
  try {
    await ElMessageBox.confirm(
      `确定撤回内容「${row.title}」吗？撤回后回到草稿状态，可以继续编辑。`,
      '撤回',
      { type: 'warning' }
    )
  } catch {
    return
  }
  await withdrawNote(row.id)
  ElMessage.success('已撤回')
  loadList()
}

async function openReviewHistory(row: AdminNote) {
  reviewDialog.visible = true
  reviewDialog.loading = true
  reviewDialog.title = `${row.title} · 审核历史`
  try {
    const result = await fetchNoteReviews(row.id)
    reviewDialog.items = result.items
  } catch {
    reviewDialog.items = []
  } finally {
    reviewDialog.loading = false
  }
}

// 标签下拉
async function loadTags() {
  if (!userStore.hasPermission('content:tag:list')) return
  const result = await fetchTags({ page: 1, per_page: 100 })
  tagOptions.value = result.items
}

onMounted(() => {
  loadList()
  loadTags()
})
</script>

<style scoped>
.page-hint {
  margin-right: 12px;
  font-size: 13px;
  color: var(--el-text-color-secondary);
}

.cover-thumb {
  width: 50px;
  height: 50px;
  border-radius: 6px;
  display: block;
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}
.gen-row {
  display: flex;
  gap: 8px;
  width: 100%;
}
.hint {
  margin-left: 10px;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}
.hint.block {
  display: block;
  margin-left: 0;
  margin-top: 8px;
}
.author-text {
  color: var(--el-text-color-primary);
}
.section-tip {
  margin: -6px 0 12px;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}
.section-card {
  margin-bottom: 14px;
  padding: 12px 12px 2px;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 8px;
  background: var(--el-fill-color-blank);
}
.section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}
.section-title {
  font-weight: 600;
  color: var(--el-text-color-primary);
}
.section-check {
  margin-left: 12px;
}
.upload-block {
  width: 100%;
}
.thumb-grid,
.cover-picker {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}
.thumb {
  position: relative;
  width: 84px;
  height: 84px;
  overflow: hidden;
  border-radius: 8px;
  border: 1px solid var(--el-border-color-lighter);
}
.thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.thumb__del {
  position: absolute;
  top: 2px;
  right: 2px;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.55);
  color: #fff;
  font-size: 12px;
  cursor: pointer;
}
.cover-option {
  position: relative;
  width: 100px;
  height: 100px;
  overflow: hidden;
  border-radius: 8px;
  border: 2px solid transparent;
  cursor: pointer;
}
.cover-option.is-active {
  border-color: var(--el-color-primary);
}
.cover-option img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.cover-option__tag {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  padding: 2px 0;
  background: rgba(0, 0, 0, 0.55);
  color: #fff;
  font-size: 11px;
  text-align: center;
}

/* 审核时间线 */
.review-timeline-main {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 4px;
}
.review-status-change {
  font-size: 13px;
  color: var(--el-text-color-regular);
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.change-arrow {
  font-size: 13px;
  color: var(--el-text-color-secondary);
}
.review-timeline-sub {
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
.review-timeline-sub .reviewer {
  margin-right: 8px;
}
.review-timeline-sub .reason {
  color: var(--el-color-danger);
}
</style>
