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
        <el-button type="primary" :icon="Search" @click="handleSearch">查询</el-button>
        <el-button :icon="Refresh" @click="handleReset">重置</el-button>

        <div class="spacer" />

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
        <el-table-column prop="title" label="标题" min-width="240" show-overflow-tooltip />
        <el-table-column prop="author_name" label="作者" width="130" />
        <el-table-column prop="channel" label="频道" width="100" />
        <el-table-column prop="likes_count" label="点赞数" width="90" />
        <el-table-column prop="sort" label="排序" width="80" />
        <el-table-column label="创建时间" width="170">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <el-button v-perm="'content:note:update'" link type="primary" @click="openEdit(row)">
              编辑
            </el-button>
            <el-button v-perm="'content:note:delete'" link type="danger" @click="handleDelete(row)">
              删除
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
      width="600px"
      @closed="resetForm"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="标题" prop="title">
          <el-input v-model="form.title" placeholder="请输入标题" maxlength="100" show-word-limit />
        </el-form-item>

        <el-form-item label="封面地址" prop="cover_url">
          <el-input v-model="form.cover_url" placeholder="图片直链，或下方用提示词生成" />
        </el-form-item>

        <!-- 便捷工具：填提示词 -> 调用文生图服务拼出封面地址，并自动带上宽高比 -->
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

        <el-form-item label="作者">
          <span class="author-text">{{ form.author_name || currentUserName }}</span>
          <span class="hint">
            {{ hasOwnAvatar ? '你已设置头像，后台与社区将显示你的头像' : '作者由当前登录用户决定，不可修改' }}
          </span>
        </el-form-item>

        <el-form-item label="频道" prop="channel">
          <el-select
            v-model="form.channel"
            placeholder="选择或输入新频道"
            filterable
            allow-create
            default-first-option
            style="width: 100%"
          >
            <el-option v-for="item in channelOptions" :key="item" :label="item" :value="item" />
          </el-select>
        </el-form-item>

        <!-- 作者已有头像时，这个兜底色不参与展示，直接隐藏避免误解 -->
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
        <el-button type="primary" :loading="submitting" @click="handleSubmit">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import { Plus, Refresh, Search } from '@element-plus/icons-vue'
import { createNote, deleteNote, fetchNotes, updateNote } from '@/api/note'
import { useUserStore } from '@/stores/user'
import { formatTime } from '@/utils/format'
import type { AdminNote, NotePayload } from '@/types'

const userStore = useUserStore()
const currentUserName = computed(() => userStore.displayName)
// 当前登录用户是否已有头像：有的话「头像颜色」这个兜底字段就用不上
const hasOwnAvatar = computed(() => Boolean(userStore.userInfo?.avatar_url))

/** 文生图服务地址，和 seed 里用的是同一个 */
const IMAGE_API_BASE = 'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image'
/** 可选尺寸，及各自对应的宽高比（宽 / 高） */
const COVER_SIZES = ['square_hd', 'square', 'portrait_4_3', 'portrait_16_9', 'landscape_4_3', 'landscape_16_9']
const SIZE_RATIOS: Record<string, number> = {
  square_hd: 1,
  square: 1,
  portrait_4_3: 0.75,
  portrait_16_9: 0.5625,
  landscape_4_3: 1.3333,
  landscape_16_9: 1.7778
}
/** 虚拟频道「推荐」不是真实数据，新增时不应该选它 */
const ALL_CHANNEL = '推荐'

const loading = ref(false)
const submitting = ref(false)
const dialogVisible = ref(false)
const isCreate = ref(true)
const list = ref<AdminNote[]>([])
const total = ref(0)
const channels = ref<string[]>([])

const query = reactive({
  page: 1,
  per_page: 10,
  keyword: '',
  channel: undefined as string | undefined
})

const formRef = ref<FormInstance>()
const form = reactive({
  id: 0,
  title: '',
  cover_url: '',
  cover_ratio: 1,
  author_name: '',
  avatar_color: '#ff6b6b',
  channel: '',
  sort: 0
})

// 提示词生成工具的本地状态（不提交给后端）
const genPrompt = ref('')
const genSize = ref(COVER_SIZES[0])

const channelOptions = computed(() => channels.value.filter((item) => item !== ALL_CHANNEL))

const rules: FormRules = {
  title: [{ required: true, message: '请输入标题', trigger: 'blur' }],
  cover_url: [{ required: true, message: '请输入封面地址', trigger: 'blur' }],
  channel: [{ required: true, message: '请选择或输入频道', trigger: 'change' }],
  cover_ratio: [{ required: true, message: '请输入宽高比', trigger: 'blur' }],
  avatar_color: [
    { required: true, message: '请选择头像颜色', trigger: 'change' },
    { pattern: /^#[0-9a-fA-F]{6}$/, message: '必须是 #RRGGBB 格式', trigger: 'change' }
  ]
}

async function loadList() {
  loading.value = true
  try {
    const result = await fetchNotes({
      page: query.page,
      per_page: query.per_page,
      keyword: query.keyword || undefined,
      channel: query.channel
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
  genPrompt.value = ''
  genSize.value = COVER_SIZES[0]
}

function openCreate() {
  isCreate.value = true
  dialogVisible.value = true
}

function openEdit(row: AdminNote) {
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
}

/** 用提示词 + 尺寸拼出封面地址，并同步宽高比 */
function generateCover() {
  if (!genPrompt.value.trim()) {
    ElMessage.warning('请先输入提示词')
    return
  }

  form.cover_url = `${IMAGE_API_BASE}?prompt=${encodeURIComponent(genPrompt.value.trim())}&image_size=${genSize.value}`
  form.cover_ratio = SIZE_RATIOS[genSize.value] ?? 1
  ElMessage.success('已生成封面地址')
}

function buildPayload(): NotePayload {
  return {
    title: form.title.trim(),
    cover_url: form.cover_url.trim(),
    cover_ratio: form.cover_ratio,
    avatar_color: form.avatar_color,
    channel: form.channel.trim(),
    sort: form.sort
  }
}

async function handleSubmit() {
  if (!formRef.value) return
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
    // 错误提示已统一处理
  } finally {
    submitting.value = false
  }
}

async function handleDelete(row: AdminNote) {
  try {
    await ElMessageBox.confirm(`确定删除内容「${row.title}」吗？`, '提示', { type: 'warning' })
  } catch {
    return
  }
  await deleteNote(row.id)
  ElMessage.success('删除成功')
  loadList()
}

onMounted(() => {
  loadList()
})
</script>

<style scoped>
.cover-thumb {
  width: 50px;
  height: 50px;
  border-radius: 6px;
  display: block;
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

.author-text {
  color: var(--el-text-color-primary);
}
</style>
