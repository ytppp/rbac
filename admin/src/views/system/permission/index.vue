<template>
  <div class="page-container">
    <div class="page-card">
      <div class="table-toolbar">
        <el-input
          v-model="query.keyword"
          placeholder="搜索权限名称 / 编码"
          clearable
          style="width: 220px"
          @keyup.enter="loadList"
        />
        <el-select v-model="query.type" placeholder="类型" clearable style="width: 120px" @change="loadList">
          <el-option label="菜单" :value="0" />
          <el-option label="按钮" :value="1" />
        </el-select>
        <el-select v-model="query.status" placeholder="状态" clearable style="width: 120px" @change="loadList">
          <el-option label="启用" :value="1" />
          <el-option label="禁用" :value="0" />
        </el-select>
        <el-button type="primary" :icon="Search" @click="loadList">查询</el-button>
        <el-button :icon="Refresh" @click="handleReset">重置</el-button>

        <div class="spacer" />

        <el-button v-perm="'system:permission:create'" type="primary" :icon="Plus" @click="openCreate()">
          新增权限
        </el-button>
      </div>

      <el-alert
        v-if="query.keyword"
        type="info"
        :closable="false"
        title="搜索模式下以平铺列表展示（不保留层级）"
        class="tree-tip"
      />

      <el-table
        v-loading="loading"
        :data="list"
        row-key="id"
        border
        default-expand-all
        :tree-props="{ children: 'children' }"
      >
        <el-table-column prop="name" label="名称" min-width="180" />
        <el-table-column prop="code" label="权限编码" min-width="200" />
        <el-table-column label="类型" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="row.type === 0 ? 'primary' : 'info'" size="small">{{ row.type_text }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="path" label="路由地址" min-width="150" />
        <el-table-column prop="component" label="组件路径" min-width="170" />
        <el-table-column prop="icon" label="图标" width="140" align="center">
          <template #default="{ row }">
            <el-icon v-if="row.icon"><component :is="row.icon" /></el-icon>
            <span class="icon-name">{{ row.icon }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="sort" label="排序" width="70" align="center" />
        <el-table-column label="状态" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" size="small">
              {{ row.status_text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button
              v-perm="'system:permission:create'"
              link
              type="primary"
              :disabled="row.type !== 0"
              @click="openCreate(row)"
            >
              新增子级
            </el-button>
            <el-button v-perm="'system:permission:update'" link type="primary" @click="openEdit(row)">
              编辑
            </el-button>
            <el-button v-perm="'system:permission:delete'" link type="danger" @click="handleDelete(row)">
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <el-dialog
      v-model="dialogVisible"
      :title="isCreate ? '新增权限' : '编辑权限'"
      width="620px"
      @closed="resetForm"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="类型" prop="type">
          <el-radio-group v-model="form.type">
            <el-radio :value="0">菜单</el-radio>
            <el-radio :value="1">按钮 / 接口</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="名称" prop="name">
          <el-input v-model="form.name" placeholder="如：用户管理 / 新增用户" />
        </el-form-item>
        <el-form-item label="权限编码" prop="code">
          <el-input v-model="form.code" placeholder="如：system:user:create" />
        </el-form-item>
        <el-form-item label="上级节点">
          <el-tree-select
            v-model="form.parent_id"
            :data="parentOptions"
            check-strictly
            clearable
            :render-after-expand="false"
            placeholder="不选则为顶级菜单"
            style="width: 100%"
          />
        </el-form-item>

        <template v-if="form.type === 0">
          <el-form-item label="路由地址" prop="path">
            <el-input v-model="form.path" placeholder="如：/system/user" />
          </el-form-item>
          <el-form-item label="组件路径" prop="component">
            <el-input v-model="form.component" placeholder="如：system/user/index（目录节点可留空）" />
          </el-form-item>
          <el-form-item label="图标">
            <el-input v-model="form.icon" placeholder="Element Plus 图标名，如 User" />
          </el-form-item>
        </template>

        <el-form-item label="排序">
          <el-input-number v-model="form.sort" :min="0" :max="9999" />
        </el-form-item>
        <el-form-item label="状态">
          <el-radio-group v-model="form.status">
            <el-radio :value="1">启用</el-radio>
            <el-radio :value="0">禁用</el-radio>
          </el-radio-group>
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
import {
  createPermission,
  deletePermission,
  fetchPermissionOptions,
  fetchPermissions,
  updatePermission
} from '@/api/permission'
import type { Permission, PermissionOption, PermissionType } from '@/types'

interface OptionNode {
  value: number
  label: string
  children?: OptionNode[]
}

const loading = ref(false)
const submitting = ref(false)
const dialogVisible = ref(false)
const isCreate = ref(true)
const list = ref<Permission[]>([])
const optionList = ref<PermissionOption[]>([])

const query = reactive({
  keyword: '',
  type: undefined as PermissionType | undefined,
  status: undefined as number | undefined
})

const formRef = ref<FormInstance>()
const form = reactive({
  id: 0,
  name: '',
  code: '',
  type: 0 as PermissionType,
  parent_id: null as number | null,
  path: '',
  component: '',
  icon: '',
  sort: 0,
  status: 1
})

const rules: FormRules = {
  name: [{ required: true, message: '请输入名称', trigger: 'blur' }],
  code: [
    { required: true, message: '请输入权限编码', trigger: 'blur' },
    {
      pattern: /^[a-z][a-z0-9_]*(:{1,2}[a-z0-9_]+)*$/,
      message: '只能使用小写字母、数字、下划线和冒号，且以字母开头',
      trigger: 'blur'
    }
  ],
  path: [
    {
      validator: (_rule, value, callback) => {
        if (form.type !== 0) return callback()
        if (!value) return callback(new Error('菜单必须填写路由地址'))
        return callback()
      },
      trigger: 'blur'
    }
  ]
}

/** 编辑时排除自身与所有后代，避免形成循环层级 */
const excludeIds = computed(() => {
  if (isCreate.value || !form.id) return []
  return collectDescendantIds(optionList.value, form.id)
})

const parentOptions = computed(() => buildOptionTree(optionList.value, excludeIds.value))

function collectDescendantIds(flat: PermissionOption[], rootId: number): number[] {
  const ids = [rootId]
  let changed = true

  while (changed) {
    changed = false
    flat.forEach((item) => {
      if (item.parent_id && ids.includes(item.parent_id) && !ids.includes(item.id)) {
        ids.push(item.id)
        changed = true
      }
    })
  }

  return ids
}

function buildOptionTree(flat: PermissionOption[], exclude: number[]): OptionNode[] {
  const menus = flat.filter((item) => item.type === 0 && !exclude.includes(item.id))
  const map = new Map<number, OptionNode>()
  menus.forEach((item) => map.set(item.id, { value: item.id, label: item.name, children: [] }))

  const roots: OptionNode[] = []
  menus.forEach((item) => {
    const node = map.get(item.id)!
    const parent = item.parent_id ? map.get(item.parent_id) : undefined
    if (parent) {
      parent.children!.push(node)
    } else {
      roots.push(node)
    }
  })

  const prune = (nodes: OptionNode[]) => {
    nodes.forEach((node) => {
      if (!node.children || node.children.length === 0) {
        delete node.children
      } else {
        prune(node.children)
      }
    })
  }
  prune(roots)

  return roots
}

async function loadList() {
  loading.value = true
  try {
    const result = await fetchPermissions({
      keyword: query.keyword || undefined,
      type: query.type,
      status: query.status
    })
    list.value = result.items
  } finally {
    loading.value = false
  }
}

async function loadOptions() {
  const result = await fetchPermissionOptions()
  optionList.value = result.items
}

function handleReset() {
  query.keyword = ''
  query.type = undefined
  query.status = undefined
  loadList()
}

function resetForm() {
  formRef.value?.resetFields()
  form.id = 0
  form.name = ''
  form.code = ''
  form.type = 0
  form.parent_id = null
  form.path = ''
  form.component = ''
  form.icon = ''
  form.sort = 0
  form.status = 1
}

function openCreate(parent?: Permission) {
  isCreate.value = true
  dialogVisible.value = true
  if (parent) {
    form.parent_id = parent.id
    form.type = 0
  }
}

function openEdit(row: Permission) {
  isCreate.value = false
  dialogVisible.value = true
  form.id = row.id
  form.name = row.name
  form.code = row.code
  form.type = row.type
  form.parent_id = row.parent_id
  form.path = row.path || ''
  form.component = row.component || ''
  form.icon = row.icon || ''
  form.sort = row.sort
  form.status = row.status
}

async function handleSubmit() {
  if (!formRef.value) return
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  const payload = {
    name: form.name,
    code: form.code,
    type: form.type,
    parent_id: form.parent_id,
    sort: form.sort,
    status: form.status,
    // 按钮类型不带路由信息
    path: form.type === 0 ? form.path : null,
    component: form.type === 0 ? form.component || null : null,
    icon: form.type === 0 ? form.icon || null : null
  }

  submitting.value = true
  try {
    if (isCreate.value) {
      await createPermission(payload)
      ElMessage.success('新增成功')
    } else {
      await updatePermission(form.id, payload)
      ElMessage.success('保存成功')
    }
    dialogVisible.value = false
    await Promise.all([loadList(), loadOptions()])
  } catch {
    // 错误提示已统一处理
  } finally {
    submitting.value = false
  }
}

async function handleDelete(row: Permission) {
  try {
    await ElMessageBox.confirm(`确定删除「${row.name}」吗？`, '提示', { type: 'warning' })
  } catch {
    return
  }
  await deletePermission(row.id)
  ElMessage.success('删除成功')
  await Promise.all([loadList(), loadOptions()])
}

onMounted(() => {
  loadOptions()
  loadList()
})
</script>

<style scoped>
.tree-tip {
  margin-bottom: 12px;
}

.icon-name {
  margin-left: 6px;
  color: #909399;
  font-size: 12px;
}
</style>
