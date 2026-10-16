<template>
  <div class="page-container">
    <div class="page-card">
      <div class="table-toolbar">
        <el-input
          v-model="query.keyword"
          placeholder="搜索邮箱 / 昵称"
          clearable
          style="width: 220px"
          @keyup.enter="handleSearch"
        />
        <el-select v-model="query.status" placeholder="账号状态" clearable style="width: 130px">
          <el-option label="启用" :value="1" />
          <el-option label="禁用" :value="0" />
        </el-select>
        <el-select v-model="query.role_id" placeholder="所属角色" clearable style="width: 170px">
          <el-option v-for="role in roleOptions" :key="role.id" :label="role.name" :value="role.id" />
        </el-select>
        <el-button type="primary" :icon="Search" @click="handleSearch">查询</el-button>
        <el-button :icon="Refresh" @click="handleReset">重置</el-button>

        <div class="spacer" />

        <el-button v-perm="'system:user:create'" type="primary" :icon="Plus" @click="openCreate">
          新增用户
        </el-button>
      </div>

      <el-table v-loading="loading" :data="list" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column label="头像" width="80">
          <template #default="{ row }">
            <!-- 有头像显示头像，没有则维持后台一贯的通用图标 -->
            <el-avatar v-if="row.avatar_url" :src="row.avatar_url" :size="32" />
            <el-avatar v-else :size="32" class="avatar-empty">
              <el-icon><UserFilled /></el-icon>
            </el-avatar>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="昵称" min-width="120" />
        <el-table-column prop="email" label="邮箱" min-width="200" />
        <el-table-column label="角色" min-width="180">
          <template #default="{ row }">
            <el-tag v-for="role in row.roles" :key="role.id" size="small" class="tag-gap">
              {{ role.name }}
            </el-tag>
            <span v-if="!row.roles || row.roles.length === 0">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-switch
              :model-value="row.status === 1"
              :disabled="row.id === userStore.userInfo?.id || !canManage(row)"
              :before-change="() => toggleStatus(row)"
            />
          </template>
        </el-table-column>
        <el-table-column label="最近登录" width="170">
          <template #default="{ row }">{{ formatTime(row.last_login_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <el-tooltip :content="PROTECTED_TIP" :disabled="canManage(row)">
              <span class="action-group">
                <el-button
                  v-perm="'system:user:update'"
                  link
                  type="primary"
                  :disabled="!canManage(row)"
                  @click="openEdit(row)"
                >
                  编辑
                </el-button>
                <el-button
                  v-perm="'system:user:update'"
                  link
                  type="primary"
                  :disabled="!canManage(row)"
                  @click="openReset(row)"
                >
                  重置密码
                </el-button>
                <el-button
                  v-perm="'system:user:delete'"
                  link
                  type="danger"
                  :disabled="!canManage(row)"
                  @click="handleDelete(row)"
                >
                  删除
                </el-button>
              </span>
            </el-tooltip>
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
      :title="isCreate ? '新增用户' : '编辑用户'"
      width="520px"
      @closed="resetForm"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="邮箱" prop="email">
          <el-input v-model="form.email" placeholder="请输入邮箱" />
        </el-form-item>
        <el-form-item label="昵称" prop="name">
          <el-input v-model="form.name" placeholder="请输入昵称" />
        </el-form-item>
        <el-form-item v-if="isCreate" label="密码" prop="password">
          <el-input v-model="form.password" type="password" placeholder="至少 6 位" show-password />
        </el-form-item>
        <el-form-item label="角色" prop="role_ids">
          <el-select v-model="form.role_ids" multiple placeholder="请选择角色" style="width: 100%">
            <el-option v-for="role in roleOptions" :key="role.id" :label="role.name" :value="role.id" />
          </el-select>
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

    <!-- 重置密码 -->
    <el-dialog v-model="resetVisible" title="重置密码" width="420px" @closed="resetPasswordForm">
      <el-form ref="resetFormRef" :model="resetPasswordData" :rules="resetRules" label-width="90px">
        <el-form-item label="新密码" prop="password">
          <el-input v-model="resetPasswordData.password" type="password" placeholder="至少 6 位" show-password />
        </el-form-item>
        <el-form-item label="确认密码" prop="password_confirmation">
          <el-input
            v-model="resetPasswordData.password_confirmation"
            type="password"
            placeholder="请再次输入新密码"
            show-password
          />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="resetVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="handleResetPassword">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import { Plus, Refresh, Search, UserFilled } from '@element-plus/icons-vue'
import { createUser, deleteUser, fetchUsers, resetUserPassword, updateUser, updateUserStatus } from '@/api/user'
import { fetchRoleOptions } from '@/api/role'
import { SUPER_ADMIN_ROLE, useUserStore } from '@/stores/user'
import { formatTime } from '@/utils/format'
import type { RoleOption, UserInfo } from '@/types'

const userStore = useUserStore()

const PROTECTED_TIP = '超级管理员账号仅超级管理员可操作'

const loading = ref(false)
const submitting = ref(false)
const dialogVisible = ref(false)
const isCreate = ref(true)
const list = ref<UserInfo[]>([])
const total = ref(0)
const roleOptions = ref<RoleOption[]>([])

const query = reactive({
  page: 1,
  per_page: 10,
  keyword: '',
  status: undefined as number | undefined,
  role_id: undefined as number | undefined
})

const formRef = ref<FormInstance>()
const form = reactive({
  id: 0,
  email: '',
  name: '',
  password: '',
  status: 1,
  role_ids: [] as number[]
})

const rules: FormRules = {
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '邮箱格式不正确', trigger: 'blur' }
  ],
  name: [{ required: true, message: '请输入昵称', trigger: 'blur' }],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码至少 6 位', trigger: 'blur' }
  ],
  role_ids: [{ required: true, message: '请至少选择一个角色', trigger: 'change' }]
}

const resetFormRef = ref<FormInstance>()
const resetVisible = ref(false)
const resetTargetId = ref(0)
const resetPasswordData = reactive({ password: '', password_confirmation: '' })
const resetRules: FormRules = {
  password: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 6, message: '密码至少 6 位', trigger: 'blur' }
  ],
  password_confirmation: [
    {
      validator: (_rule, value, callback) => {
        if (!value) return callback(new Error('请再次输入新密码'))
        if (value !== resetPasswordData.password) return callback(new Error('两次输入的密码不一致'))
        return callback()
      },
      trigger: 'blur'
    }
  ]
}

/** 该行是否为超级管理员账号 */
function isSuperAdminRow(row: UserInfo) {
  return (row.roles || []).some((role) => role.code === SUPER_ADMIN_ROLE)
}

/** 当前登录人能否操作该行：超管账号只有超管能动 */
function canManage(row: UserInfo) {
  return userStore.isSuperAdmin || !isSuperAdminRow(row)
}

async function loadList() {
  loading.value = true
  try {
    const result = await fetchUsers({
      page: query.page,
      per_page: query.per_page,
      keyword: query.keyword || undefined,
      status: query.status,
      role_id: query.role_id
    })
    list.value = result.items
    total.value = result.meta.total
  } finally {
    loading.value = false
  }
}

async function loadRoleOptions() {
  const result = await fetchRoleOptions()
  roleOptions.value = result.items
}

function handleSearch() {
  query.page = 1
  loadList()
}

function handleReset() {
  query.keyword = ''
  query.status = undefined
  query.role_id = undefined
  handleSearch()
}

function resetForm() {
  formRef.value?.resetFields()
  form.id = 0
  form.email = ''
  form.name = ''
  form.password = ''
  form.status = 1
  form.role_ids = []
}

function openCreate() {
  isCreate.value = true
  dialogVisible.value = true
}

function openEdit(row: UserInfo) {
  isCreate.value = false
  dialogVisible.value = true
  form.id = row.id
  form.email = row.email
  form.name = row.name
  form.status = row.status
  form.role_ids = row.role_ids ? [...row.role_ids] : []
}

async function handleSubmit() {
  if (!formRef.value) return
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    if (isCreate.value) {
      await createUser({
        email: form.email,
        name: form.name,
        password: form.password,
        status: form.status,
        role_ids: form.role_ids
      })
      ElMessage.success('新增成功')
    } else {
      await updateUser(form.id, {
        email: form.email,
        name: form.name,
        status: form.status,
        role_ids: form.role_ids
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

async function toggleStatus(row: UserInfo) {
  const nextStatus = row.status === 1 ? 0 : 1
  try {
    await updateUserStatus(row.id, nextStatus)
    ElMessage.success(nextStatus === 1 ? '已启用' : '已禁用')
    await loadList()
    return true
  } catch {
    return false
  }
}

function openReset(row: UserInfo) {
  resetTargetId.value = row.id
  resetVisible.value = true
}

function resetPasswordForm() {
  resetFormRef.value?.resetFields()
  resetPasswordData.password = ''
  resetPasswordData.password_confirmation = ''
}

async function handleResetPassword() {
  if (!resetFormRef.value) return
  const valid = await resetFormRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    await resetUserPassword(resetTargetId.value, {
      password: resetPasswordData.password,
      password_confirmation: resetPasswordData.password_confirmation
    })
    ElMessage.success('密码已重置')
    resetVisible.value = false
  } catch {
    // 错误提示已统一处理
  } finally {
    submitting.value = false
  }
}

async function handleDelete(row: UserInfo) {
  try {
    await ElMessageBox.confirm(`确定删除用户「${row.name}」吗？`, '提示', { type: 'warning' })
  } catch {
    return
  }
  await deleteUser(row.id)
  ElMessage.success('删除成功')
  loadList()
}

onMounted(() => {
  loadRoleOptions()
  loadList()
})
</script>

<style scoped>
.tag-gap {
  margin-right: 6px;
}

.action-group {
  display: inline-block;
}

.avatar-empty {
  background: #c0c4cc;
}
</style>
