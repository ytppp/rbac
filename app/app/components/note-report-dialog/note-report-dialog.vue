<template>
  <el-dialog v-model="visible" :title="$t('report.title')" width="420px">
    <el-form label-position="top">
      <el-form-item :label="$t('report.reason')">
        <el-select v-model="form.reason" style="width: 100%">
          <el-option
            v-for="item in reasons"
            :key="item.value"
            :label="item.label"
            :value="item.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item :label="$t('report.detail')">
        <el-input
          v-model="form.detail"
          type="textarea"
          :rows="3"
          maxlength="500"
          show-word-limit
          :placeholder="$t('report.detailPlaceholder')"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="visible = false">{{ $t('common.cancel') }}</el-button>
      <el-button type="primary" :loading="submitting" @click="submit">
        {{ $t('report.submit') }}
      </el-button>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { useAuth } from '~/composables/useAuth'

interface ReportTarget {
  type: 'note' | 'comment'
  id: number
}

const props = defineProps<{
  visible: boolean
  target: ReportTarget
}>()

const emit = defineEmits<{
  (e: 'update:visible', v: boolean): void
  (e: 'success'): void
}>()

const { t } = useI18n()
const { authHeaders } = useAuth()

const submitting = ref(false)
const form = reactive({ reason: 'spam', detail: '' })

const reasons = computed(() =>
  ['spam', 'ads', 'abuse', 'copyright', 'other'].map((value) => ({
    value,
    label: t(`report.reasons.${value}`),
  })),
)

// 每次打开重置表单
watch(() => props.visible, (v) => {
  if (v) {
    form.reason = 'spam'
    form.detail = ''
  }
})

const visible = computed({
  get: () => props.visible,
  set: (v) => emit('update:visible', v),
})

async function submit() {
  submitting.value = true
  try {
    const path = props.target.type === 'note'
      ? `/notes/${props.target.id}/reports`
      : `/comments/${props.target.id}/reports`

    await $fetch(path, {
      baseURL: useApiBase(),
      method: 'POST',
      headers: authHeaders(),
      body: { reason: form.reason, detail: form.detail.trim() },
    })
    ElMessage.success(t('report.success'))
    visible.value = false
    emit('success')
  } catch (err: any) {
    ElMessage.error(err?.data?.error || t('report.failed'))
  } finally {
    submitting.value = false
  }
}
</script>
