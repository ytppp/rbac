<template>
  <div class="page-container">
    <div class="page-card">
      <div class="table-toolbar">
        <el-input
          v-model="query.keyword"
          placeholder="搜索角色名称 / 编码"
          clearable
          style="width: 220px"
          @keyup.enter="handleSearch"
        />
        <el-select v-model="query.status" placeholder="状态" clearable style="width: 130px">
          <el-option label="启用" :value="1" />
          <el-option label="禁用" :value="0" />
        </el-select>
        <el-button type="primary" :icon="Search" @click="handleSearch">查询</el-button>
        <el-button :icon="Refresh" @click="handleReset">重置</el-button>

        <div class="spacer" />

        <el-button v-perm="'system:role:create'" type="primary" :icon="Plus" @click="openCreate">
          新增角色
        </el-button>
      </div>

      <el-table v-loading="loading" :data="list" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="name" label="角色名称" min-width="140" />
        <el-table-column prop="code" label="角色编码" min-width="160" />
        <el-table-column prop="description" label="描述" min-width="220" show-overflow-tooltip />
        <el-table-column label="用户数" width="90" align="center">
          <template #default="{ row }">{{ row.user_count }}</template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" size="small">
              {{ row.status_text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="内置" width="80">
          <template #default="{ row }">
            <el-tag v-if="row.built_in" type="danger" size="small">内置</el-tag>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button v-perm="'system:role:update'" link type="primary" @click="openEdit(row)">
              编辑
            </el-button>
            <el-button
              v-perm="'system:role:delete'"
              link
              type="danger"
              :disabled="row.built_in"
              @click="handleDelete(row)"
            >
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
      :title="isCreate ? '新增角色' : '编辑角色'"
      width="620px"
      @closed="resetForm"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="角色名称" prop="name">
          <el-input v-model="form.name" placeholder="请输入角色名称" />
        </el-form-item>
        <el-form-item label="角色编码" prop="code">
          <el-input
            v-model="form.code"
            placeholder="小写字母、数字、下划线，如 user_manager"
            :disabled="codeLocked"
          />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="form.description" type="textarea" :rows="2" placeholder="可选" />
        </el-form-item>
        <el-form-item label="状态">
          <el-radio-group v-model="form.status">
            <el-radio :value="1">启用</el-radio>
            <el-radio :value="0">禁用</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="权限分配">
          <div class="permission-tree-wrapper">
            <el-tree
              ref="treeRef"
              :data="permissionTree"
              node-key="id"
              show-checkbox
              default-expand-all
              :props="{ label: 'name', children: 'children' }"
            >
              <template #default="{ data }">
                <span>
                  {{ data.name }}
                  <el-tag size="small" :type="data.type === 0 ? 'primary' : 'info'" class="node-tag">
                    {{ data.type === 0 ? '菜单' : '按钮' }}
                  </el-tag>
                  <span class="node-code">{{ data.code }}</span>
                </span>
              </template>
            </el-tree>
          </div>
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
import { nextTick, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import { Plus, Refresh, Search } from '@element-plus/icons-vue'
import { createRole, deleteRole, fetchRole, fetchRoles, updateRole } from '@/api/role'
import { fetchPermissions } from '@/api/permission'
import type { Permission, Role } from '@/types'

const loading = ref(false)
const submitting = ref(false)
const dialogVisible = ref(false)
const isCreate = ref(true)
const codeLocked = ref(false)
const list = ref<Role[]>([])
const total = ref(0)
const permissionTree = ref<Permission[]>([])
const treeRef = ref()

const query = reactive({
  page: 1,
  per_page: 10,
  keyword: '',
  status: undefined as number | undefined
})

const formRef = ref<FormInstance>()
const form = reactive({
  id: 0,
  name: '',
  code: '',
  description: '',
  status: 1
})

const rules: FormRules = {
  name: [{ required: true, message: '请输入角色名称', trigger: 'blur' }],
  code: [
    { required: true, message: '请输入角色编码', trigger: 'blur' },
    {
      pattern: /^[a-z][a-z0-9_]{1,49}$/,
      message: '只能包含小写字母、数字和下划线，且以字母开头',
      trigger: 'blur'
    }
  ]
}

/** 收集所有叶子节点 id：只勾选叶子，父级由 el-tree 自动半选，避免父级被勾选后带出全部子权限 */
function collectLeafIds(nodes: Permission[], result: number[] = []): number[] {
  nodes.forEach((node) => {
    const children = node.children || []
    if (children.length === 0) {
      result.push(node.id)
    } else {
      collectLeafIds(children, result)
    }
  })
  return result
}

async function loadList() {
  loading.value = true
  try {
    const result = await fetchRoles({
      page: query.page,
      per_page: query.per_page,
      keyword: query.keyword || undefined,
      status: query.status
    })
    list.value = result.items
    total.value = result.meta.total
  } finally {
    loading.value = false
  }
}

async function loadPermissionTree() {
  const result = await fetchPermissions()
  permissionTree.value = result.items
}

function handleSearch() {
  query.page = 1
  loadList()
}

function handleReset() {
  query.keyword = ''
  query.status = undefined
  handleSearch()
}

function resetForm() {
  formRef.value?.resetFields()
  form.id = 0
  form.name = ''
  form.code = ''
  form.description = ''
  form.status = 1
  codeLocked.value = false
  treeRef.value?.setCheckedKeys([])
}

async function openCreate() {
  isCreate.value = true
  codeLocked.value = false
  dialogVisible.value = true
  await nextTick()
  treeRef.value?.setCheckedKeys([])
}

async function openEdit(row: Role) {
  isCreate.value = false
  codeLocked.value = row.built_in || row.super_admin
  dialogVisible.value = true

  const detail = await fetchRole(row.id)
  form.id = detail.id
  form.name = detail.name
  form.code = detail.code
  form.description = detail.description || ''
  form.status = detail.status

  const leafIds = collectLeafIds(permissionTree.value)
  const granted = detail.permission_ids || []
  await nextTick()
  treeRef.value?.setCheckedKeys(granted.filter((id) => leafIds.includes(id)))
}

async function handleSubmit() {
  if (!formRef.value) return
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  // 半选中的父级菜单也要一并提交，否则菜单不会出现在用户的侧边栏
  const checked = (treeRef.value?.getCheckedKeys() || []) as number[]
  const halfChecked = (treeRef.value?.getHalfCheckedKeys() || []) as number[]
  const permissionIds = [...checked, ...halfChecked]

  submitting.value = true
  try {
    if (isCreate.value) {
      await createRole({
        name: form.name,
        code: form.code,
        description: form.description,
        status: form.status,
        permission_ids: permissionIds
      })
      ElMessage.success('新增成功')
    } else {
      await updateRole(form.id, {
        name: form.name,
        code: form.code,
        description: form.description,
        status: form.status,
        permission_ids: permissionIds
      })
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

async function handleDelete(row: Role) {
  try {
    await ElMessageBox.confirm(`确定删除角色「${row.name}」吗？`, '提示', { type: 'warning' })
  } catch {
    return
  }
  await deleteRole(row.id)
  ElMessage.success('删除成功')
  loadList()
}

onMounted(() => {
  loadPermissionTree()
  loadList()
})
</script>

<style scoped>
.permission-tree-wrapper {
  width: 100%;
  max-height: 320px;
  overflow-y: auto;
  border: 1px solid #dcdfe6;
  border-radius: 4px;
  padding: 8px;
}

.node-tag {
  margin-left: 6px;
}

.node-code {
  margin-left: 6px;
  color: #909399;
  font-size: 12px;
}
</style>
