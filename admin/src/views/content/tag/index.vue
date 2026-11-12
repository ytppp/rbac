<template>
  <div class="page-container">
    <div class="page-card">
      <div class="table-toolbar">
        <el-input
          v-model="query.keyword"
          placeholder="搜索标签名"
          clearable
          style="width: 220px"
          @keyup.enter="handleSearch"
        />
        <el-button type="primary" :icon="Search" @click="handleSearch">查询</el-button>
        <el-button :icon="Refresh" @click="handleReset">重置</el-button>

        <div class="spacer" />

        <el-button v-perm="'content:tag:create'" type="primary" :icon="Plus" @click="openCreate">
          新增标签
        </el-button>
      </div>

      <el-table v-loading="loading" :data="list" border stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="name" label="标签名" min-width="200" show-overflow-tooltip />
        <el-table-column prop="notes_count" label="内容数" width="100" />
        <el-table-column prop="sort" label="排序" width="90" />
        <el-table-column label="创建时间" width="180">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <el-button v-perm="'content:tag:update'" link type="primary" @click="openEdit(row)">
              编辑
            </el-button>
            <el-button v-perm="'content:tag:delete'" link type="danger" @click="handleDelete(row)">
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

    <el-dialog
      v-model="dialogVisible"
      :title="isCreate ? '新增标签' : '编辑标签'"
      width="420px"
      @closed="resetForm"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="80px">
        <el-form-item label="标签名" prop="name">
          <el-input v-model="form.name" placeholder="例如：自驾、海岛、露营" maxlength="20" show-word-limit />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort" :min="0" />
          <span class="hint block">数字越小越靠前</span>
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="handleSubmit">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import { Plus, Refresh, Search } from '@element-plus/icons-vue'
import { createTag, deleteTag, fetchTags, updateTag, type AdminTag } from '@/api/tag'
import { formatTime } from '@/utils/format'

const loading = ref(false)
const submitting = ref(false)
const dialogVisible = ref(false)
const isCreate = ref(true)
const list = ref<AdminTag[]>([])
const total = ref(0)

const query = reactive({
  page: 1,
  per_page: 10,
  keyword: ''
})

const formRef = ref<FormInstance>()
const form = reactive({
  id: 0,
  name: '',
  sort: 0
})

const rules: FormRules = {
  name: [
    { required: true, message: '请输入标签名', trigger: 'blur' },
    { max: 20, message: '标签名最多 20 个字', trigger: 'blur' }
  ]
}

async function loadList() {
  loading.value = true
  try {
    const result = await fetchTags({
      page: query.page,
      per_page: query.per_page,
      keyword: query.keyword || undefined
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
  query.keyword = ''
  handleSearch()
}

function resetForm() {
  formRef.value?.resetFields()
  form.id = 0
  form.name = ''
  form.sort = 0
}

function openCreate() {
  isCreate.value = true
  dialogVisible.value = true
}

function openEdit(row: AdminTag) {
  isCreate.value = false
  form.id = row.id
  form.name = row.name
  form.sort = row.sort
  dialogVisible.value = true
}

async function handleSubmit() {
  if (!formRef.value) return

  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    if (isCreate.value) {
      await createTag({ name: form.name.trim(), sort: form.sort })
      ElMessage.success('标签已创建')
    } else {
      await updateTag(form.id, { name: form.name.trim(), sort: form.sort })
      ElMessage.success('标签已更新')
    }
    dialogVisible.value = false
    loadList()
  } finally {
    submitting.value = false
  }
}

async function handleDelete(row: AdminTag) {
  await ElMessageBox.confirm(
    `确定删除标签「${row.name}」吗？删除后该标签会从所有内容上移除。`,
    '删除标签',
    { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' }
  ).catch(() => false)

  await deleteTag(row.id)
  ElMessage.success('删除成功')
  loadList()
}

onMounted(loadList)
</script>
