<template>
  <div class="page-container">
    <el-card shadow="never">
      <template #header>
        <span>基本资料</span>
      </template>

      <el-form ref="profileFormRef" :model="profileForm" :rules="profileRules" label-width="90px" class="narrow-form">
        <el-form-item label="邮箱" prop="email">
          <el-input v-model="profileForm.email" />
        </el-form-item>
        <el-form-item label="昵称" prop="name">
          <el-input v-model="profileForm.name" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="submitting" @click="handleUpdateProfile">保存</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" class="section-card">
      <template #header>
        <span>修改密码</span>
      </template>

      <el-form
        ref="passwordFormRef"
        :model="passwordForm"
        :rules="passwordRules"
        label-width="90px"
        class="narrow-form"
      >
        <el-form-item label="当前密码" prop="current_password">
          <el-input v-model="passwordForm.current_password" type="password" show-password />
        </el-form-item>
        <el-form-item label="新密码" prop="password">
          <el-input v-model="passwordForm.password" type="password" show-password />
        </el-form-item>
        <el-form-item label="确认密码" prop="password_confirmation">
          <el-input v-model="passwordForm.password_confirmation" type="password" show-password />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="submitting" @click="handleUpdatePassword">修改密码</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" class="section-card">
      <template #header>
        <span>我的角色与权限</span>
      </template>

      <el-descriptions :column="1" border>
        <el-descriptions-item label="角色">
          <el-tag v-for="role in userStore.userInfo?.roles" :key="role.id" class="tag-gap">
            {{ role.name }}（{{ role.code }}）
          </el-tag>
          <span v-if="!userStore.userInfo?.roles?.length">未分配角色</span>
        </el-descriptions-item>
        <el-descriptions-item label="权限码">
          <el-tag v-for="code in userStore.permissions" :key="code" type="info" size="small" class="tag-gap">
            {{ code }}
          </el-tag>
        </el-descriptions-item>
      </el-descriptions>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { updatePassword, updateProfile } from '@/api/auth'
import { usePermissionStore } from '@/stores/permission'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
const permissionStore = usePermissionStore()

const submitting = ref(false)

const profileFormRef = ref<FormInstance>()
const profileForm = reactive({ email: '', name: '' })
const profileRules: FormRules = {
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '邮箱格式不正确', trigger: 'blur' }
  ],
  name: [{ required: true, message: '请输入昵称', trigger: 'blur' }]
}

const passwordFormRef = ref<FormInstance>()
const passwordForm = reactive({
  current_password: '',
  password: '',
  password_confirmation: ''
})
const passwordRules: FormRules = {
  current_password: [{ required: true, message: '请输入当前密码', trigger: 'blur' }],
  password: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 6, message: '新密码至少 6 位', trigger: 'blur' }
  ],
  password_confirmation: [
    {
      validator: (_rule, value, callback) => {
        if (!value) return callback(new Error('请再次输入新密码'))
        if (value !== passwordForm.password) return callback(new Error('两次输入的密码不一致'))
        return callback()
      },
      trigger: 'blur'
    }
  ]
}

async function handleUpdateProfile() {
  if (!profileFormRef.value) return
  const valid = await profileFormRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    await updateProfile({ email: profileForm.email, name: profileForm.name })
    await userStore.fetchProfile()
    ElMessage.success('资料已更新')
  } catch {
    // 错误提示已统一处理
  } finally {
    submitting.value = false
  }
}

async function handleUpdatePassword() {
  if (!passwordFormRef.value) return
  const valid = await passwordFormRef.value.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    await updatePassword({ ...passwordForm })
    ElMessage.success('密码修改成功，请重新登录')
    userStore.reset()
    permissionStore.reset()
    router.replace('/login')
  } catch {
    // 错误提示已统一处理
  } finally {
    submitting.value = false
  }
}

onMounted(async () => {
  if (!userStore.userInfo) {
    await userStore.fetchProfile()
  }
  profileForm.email = userStore.userInfo?.email || ''
  profileForm.name = userStore.userInfo?.name || ''
})
</script>

<style scoped>
.narrow-form {
  max-width: 460px;
}

.section-card {
  margin-top: 16px;
}

.tag-gap {
  margin: 0 8px 8px 0;
}
</style>
