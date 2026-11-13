<template>
  <div class="page-container">
    <div class="page-card">
      <el-tabs v-model="activeScope" class="review-tabs" @tab-change="handleScopeChange">
        <el-tab-pane label="待审核" name="pending">
          <template #label>
            <span>待审核</span>
            <el-badge v-if="pendingCount > 0" :value="pendingCount" class="tab-badge" />
          </template>
        </el-tab-pane>
        <el-tab-pane label="全部历史" name="all" />
        <el-tab-pane label="我处理的" name="my" />
      </el-tabs>

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
      </div>

      <el-table v-loading="loading" :data="list" border stripe>
        <el-table-column label="封面" width="80">
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
        <el-table-column prop="author_name" label="作者" width="120" />
        <el-table-column prop="channel" label="频道" width="100" />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="statusType(row.status)">{{ statusLabel(row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="上次动作" width="240">
          <template #default="{ row }">
            <div v-if="row.last_action" class="last-action">
              <el-tag :type="actionTagType(row.last_action)" size="small">{{ actionLabel(row.last_action) }}</el-tag>
              <span v-if="row.pending_since" class="pending-since">· {{ formatTime(row.pending_since) }}</span>
            </div>
            <span v-else class="muted">—</span>
          </template>
        </el-table-column>
        <el-table-column label="原因 / 备注" min-width="200">
          <template #default="{ row }">
            <span v-if="row.last_reason" class="reason-text" :title="row.last_reason">
              {{ row.last_reason }}
            </span>
            <span v-else class="muted">—</span>
          </template>
        </el-table-column>
        <el-table-column label="创建时间" width="170">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button
              v-if="row.status === 'pending'"
              v-perm="'content:review:approve'"
              link
              type="success"
              @click="handleApprove(row)"
            >
              通过
            </el-button>
            <el-button
              v-if="row.status === 'pending'"
              v-perm="'content:review:reject'"
              link
              type="danger"
              @click="openReject(row)"
            >
              驳回
            </el-button>
            <el-button v-perm="'content:review:history'" link type="info" @click="openNoteHistory(row)">审核历史</el-button>
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

    <!-- 驳回弹框 -->
    <el-dialog v-model="rejectDialog.visible" title="驳回审核" width="520px">
      <p class="reject-subtitle">
        你正在驳回内容「<b>{{ rejectDialog.title }}</b>」，作者看到驳回原因后可以继续编辑并重新提交。
      </p>
      <el-form-item label="驳回原因" required>
        <el-input
          v-model="rejectDialog.reason"
          type="textarea"
          :rows="4"
          placeholder="请填写具体的驳回原因，作者会直接看到这条说明"
          maxlength="500"
          show-word-limit
        />
      </el-form-item>
      <template #footer>
        <el-button @click="rejectDialog.visible = false">取消</el-button>
        <el-button type="danger" :loading="rejectDialog.submitting" @click="handleReject">确认驳回</el-button>
      </template>
    </el-dialog>

    <!-- 审核历史弹层（复用内容管理的 fetchNoteReviews 接口） -->
    <el-dialog v-model="reviewDialog.visible" :title="reviewDialog.title" width="620px" top="8vh">
      <el-timeline v-loading="reviewDialog.loading">
        <el-timeline-item
          v-for="(item, index) in reviewDialog.items"
          :key="item.id || index"
          :timestamp="formatTime(item.created_at)"
          placement="top"
          :type="reviewItemType(item)"
        >
          <div class="review-timeline-main">
            <el-tag :type="reviewItemTagType(item)" size="small">{{ reviewActionLabel(item.action) }}</el-tag>
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
import { onMounted, reactive, ref, watch } from 'vue'
import { ArrowRight } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search, Refresh } from '@element-plus/icons-vue'
import { approveReview, fetchReviewQueue, rejectReview } from '@/api/review'
import { fetchNoteReviews } from '@/api/note'
import { formatTime } from '@/utils/format'
import type { NoteStatus, ReviewQueueItem, ReviewRecord } from '@/types'

const loading = ref(false)
const list = ref<ReviewQueueItem[]>([])
const total = ref(0)
const pendingCount = ref(0) // 待审核 tab 右边角标

const activeScope = ref<'pending' | 'all' | 'my'>('pending')

const query = reactive({
  page: 1,
  per_page: 10,
  keyword: '',
  channel: undefined as string | undefined,
  status: undefined as NoteStatus | undefined
})

const channels = ref<string[]>([])

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

const ACTION_LABELS: Record<string, string> = {
  submit: '提交审核',
  approve: '审核通过',
  reject: '审核驳回',
  withdraw: '作者撤回',
  auto_pending: '内容已更新，自动重新审核',
  archive: '强制下架',
  restore: '重新发布',
  force_publish: '管理员强制发布'
}
function actionLabel(action?: string) {
  if (!action) return ''
  return ACTION_LABELS[action] ?? action
}
function actionTagType(action: string) {
  if (action === 'reject' || action === 'archive') return 'danger'
  if (action === 'approve' || action === 'restore' || action === 'force_publish') return 'success'
  if (action === 'auto_pending') return 'warning'
  return 'info'
}

function reviewActionLabel(action: string) {
  return ACTION_LABELS[action] ?? action
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

// 驳回弹框状态
const rejectDialog = reactive<{
  visible: boolean
  id: number
  title: string
  reason: string
  submitting: boolean
}>({
  visible: false,
  id: 0,
  title: '',
  reason: '',
  submitting: false
})

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

function currentScopeParam() {
  return activeScope.value === 'pending' ? 'pending' : activeScope.value === 'my' ? 'my' : 'all'
}

async function loadList() {
  loading.value = true
  try {
    const result = await fetchReviewQueue({
      page: query.page,
      per_page: query.per_page,
      keyword: query.keyword || undefined,
      channel: query.channel,
      status: query.status,
      scope: currentScopeParam()
    })
    list.value = result.items
    channels.value = result.channels
    total.value = result.meta.total
  } finally {
    loading.value = false
  }
}

async function loadPendingCount() {
  // 只拉一条待审看 total 当角标
  try {
    const result = await fetchReviewQueue({ scope: 'pending', page: 1, per_page: 1 })
    pendingCount.value = result.meta.total
  } catch {
    pendingCount.value = 0
  }
}

function handleScopeChange() {
  query.page = 1
  query.status = undefined
  loadList()
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

async function handleApprove(row: ReviewQueueItem) {
  try {
    await ElMessageBox.confirm(
      `通过内容「${row.title}」的审核？通过后会正式发布到社区。`,
      '审核通过',
      { type: 'success' }
    )
  } catch {
    return
  }
  await approveReview(row.id)
  ElMessage.success('已通过，内容已发布')
  await Promise.all([loadList(), loadPendingCount()])
}

function openReject(row: ReviewQueueItem) {
  rejectDialog.id = row.id
  rejectDialog.title = row.title
  rejectDialog.reason = ''
  rejectDialog.visible = true
}

async function handleReject() {
  const reason = rejectDialog.reason.trim()
  if (!reason) {
    ElMessage.warning('请填写驳回原因')
    return
  }
  rejectDialog.submitting = true
  try {
    await rejectReview(rejectDialog.id, reason)
    ElMessage.success('已驳回，作者会看到你的原因')
    rejectDialog.visible = false
    await Promise.all([loadList(), loadPendingCount()])
  } finally {
    rejectDialog.submitting = false
  }
}

async function openNoteHistory(row: ReviewQueueItem) {
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

// 切换 tab 时刷新角标
watch(activeScope, (val) => {
  if (val === 'pending') {
    loadPendingCount()
  }
})

onMounted(() => {
  loadList()
  loadPendingCount()
})
</script>

<style scoped>
.review-tabs {
  margin-bottom: 12px;
}
.tab-badge {
  margin-left: 4px;
}
.cover-thumb {
  width: 56px;
  height: 56px;
  border-radius: 6px;
  display: block;
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}
.last-action {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.pending-since {
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
.reason-text {
  display: inline-block;
  max-width: 280px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--el-color-danger);
  font-size: 13px;
}
.reject-subtitle {
  margin-bottom: 12px;
  font-size: 13px;
  color: var(--el-text-color-secondary);
}
.reject-subtitle b {
  color: var(--el-text-color-primary);
}
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
