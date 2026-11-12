<template>
  <div class="page-container">
    <div class="page-card">
      <div class="table-toolbar">
        <el-select v-model="query.status" placeholder="全部状态" clearable style="width: 140px">
          <el-option label="待处理" value="pending" />
          <el-option label="已处理" value="resolved" />
          <el-option label="已忽略" value="ignored" />
        </el-select>
        <el-button type="primary" :icon="Search" @click="handleSearch">查询</el-button>
        <el-button :icon="Refresh" @click="handleReset">重置</el-button>
      </div>

      <el-table v-loading="loading" :data="list" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="内容" min-width="220">
          <template #default="{ row }">
            <p class="m-0 font-600">{{ row.note.title }}</p>
            <span class="muted">内容状态：{{ noteStatusText(row.note.status) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="举报原因" width="120">
          <template #default="{ row }">{{ reasonText(row.reason) }}</template>
        </el-table-column>
        <el-table-column prop="detail" label="补充说明" min-width="160" show-overflow-tooltip />
        <el-table-column label="举报人" width="120">
          <template #default="{ row }">{{ row.reporter.name }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status === 'pending' ? 'warning' : 'info'">
              {{ statusText(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="举报时间" width="170">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 'pending'">
              <el-button v-perm="'content:report:handle'" link type="danger" @click="handle(row, 'resolved', true)">
                下架内容
              </el-button>
              <el-button v-perm="'content:report:handle'" link type="info" @click="handle(row, 'ignored', false)">
                忽略
              </el-button>
            </template>
            <span v-else class="muted">已处理</span>
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
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Search } from '@element-plus/icons-vue'
import { fetchReports, handleReport, type AdminReport } from '@/api/report'
import { formatTime } from '@/utils/format'

const loading = ref(false)
const list = ref<AdminReport[]>([])
const total = ref(0)

const query = reactive({
  page: 1,
  per_page: 10,
  status: undefined as string | undefined
})

const REASON_TEXT: Record<string, string> = {
  spam: '垃圾信息',
  ads: '广告营销',
  abuse: '辱骂或攻击',
  copyright: '侵权内容',
  other: '其他'
}

const STATUS_TEXT: Record<string, string> = {
  pending: '待处理',
  resolved: '已处理',
  ignored: '已忽略'
}

const NOTE_STATUS_TEXT: Record<string, string> = {
  draft: '草稿',
  pending: '待审',
  published: '已发布',
  archived: '已下架'
}

function reasonText(reason: string) {
  return REASON_TEXT[reason] ?? reason
}

function statusText(status: string) {
  return STATUS_TEXT[status] ?? status
}

function noteStatusText(status: string) {
  return NOTE_STATUS_TEXT[status] ?? status
}

async function loadList() {
  loading.value = true
  try {
    const result = await fetchReports({
      page: query.page,
      per_page: query.per_page,
      status: query.status
    })
    list.value = result.items
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
  query.status = undefined
  handleSearch()
}

/** 处理举报：下架会同时把内容置为已下架 */
async function handle(row: AdminReport, status: 'resolved' | 'ignored', archive: boolean) {
  if (archive) {
    const confirmed = await ElMessageBox.confirm(
      `确定下架内容「${row.note.title}」吗？下架后内容社区将不再展示。`,
      '下架内容',
      { type: 'warning', confirmButtonText: '下架', cancelButtonText: '取消' }
    ).catch(() => false)
    if (!confirmed) return
  }

  await handleReport(row.id, { status, archive_note: archive })
  ElMessage.success(archive ? '已下架并处理' : '已忽略该举报')
  loadList()
}

onMounted(loadList)
</script>
