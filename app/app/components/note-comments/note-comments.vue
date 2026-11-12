<template>
  <section class="comments">
    <header class="comments__head">
      <h2 class="comments__title">
        {{ $t('comment.title') }}
        <span class="comments__count">{{ total }}</span>
      </h2>
      <el-segmented v-model="sort" :options="sortOptions" size="small" @change="reload" />
    </header>

    <!-- 发布评论：未登录时点击输入区会引导登录 -->
    <div class="editor">
      <el-avatar :size="40" :src="user?.avatar_url || undefined" class="editor__avatar">
        {{ myInitial }}
      </el-avatar>
      <div class="editor__body">
        <el-input
          v-model="draft"
          type="textarea"
          :rows="2"
          maxlength="500"
          :placeholder="isLoggedIn ? $t('comment.placeholder') : $t('comment.loginPlaceholder')"
          resize="none"
          @focus="handleFocus"
        />
        <div class="editor__actions">
          <span class="editor__hint">{{ draft.length }}/500</span>
          <el-button
            type="primary"
            size="small"
            round
            :loading="submitting"
            :disabled="!draft.trim()"
            @click="submitComment()"
          >
            {{ $t('comment.submit') }}
          </el-button>
        </div>
      </div>
    </div>

    <ul v-if="comments.length" class="comment-list">
      <li v-for="(comment, index) in comments" :key="comment.id" class="comment">
        <el-avatar :size="40" :src="comment.author.avatar_url || undefined" class="comment__avatar">
          {{ (comment.author.name || '?').slice(0, 1) }}
        </el-avatar>

        <div class="comment__main">
          <div class="comment__meta">
            <span class="comment__name">{{ comment.author.name }}</span>
            <span class="comment__floor">{{ $t('comment.floor', { count: index + 1 }) }}</span>
            <span class="comment__time">{{ formatTime(comment.created_at) }}</span>
          </div>

          <p class="comment__content">{{ comment.content }}</p>

          <div class="comment__actions">
            <button type="button" class="action" :class="{ 'is-active': comment.liked }" @click="toggleLike(comment)">
              <icon :name="comment.liked ? 'i-carbon:thumbs-up-filled' : 'i-carbon:thumbs-up'" />
              <span v-if="comment.likes">{{ comment.likes }}</span>
            </button>
            <button type="button" class="action" @click="startReply(comment)">
              <icon name="i-carbon:reply" />
              <span>{{ $t('comment.reply') }}</span>
            </button>
            <button v-if="comment.mine" type="button" class="action" @click="removeComment(comment)">
              <icon name="i-carbon:trash-can" />
              <span>{{ $t('comment.delete') }}</span>
            </button>
          </div>

          <!-- 回复输入：挂在被回复的顶层评论下 -->
          <div v-if="replyTo === comment.id" class="reply-editor">
            <el-input
              v-model="replyDraft"
              type="textarea"
              :rows="2"
              maxlength="500"
              :placeholder="$t('comment.replyPlaceholder', { name: comment.author.name })"
              resize="none"
            />
            <div class="reply-editor__actions">
              <el-button text size="small" @click="cancelReply">{{ $t('comment.cancel') }}</el-button>
              <el-button
                type="primary"
                size="small"
                round
                :loading="submitting"
                :disabled="!replyDraft.trim()"
                @click="submitComment(comment)"
              >
                {{ $t('comment.reply') }}
              </el-button>
            </div>
          </div>

          <!-- 楼中楼：只展示一层回复 -->
          <ul v-if="comment.replies.length" class="reply-list">
            <li v-for="reply in comment.replies" :key="reply.id" class="reply">
              <el-avatar :size="26" :src="reply.author.avatar_url || undefined" class="reply__avatar">
                {{ (reply.author.name || '?').slice(0, 1) }}
              </el-avatar>
              <div class="reply__main">
                <div class="comment__meta">
                  <span class="comment__name">{{ reply.author.name }}</span>
                  <span class="reply__at">@{{ comment.author.name }}</span>
                  <span class="comment__time">{{ formatTime(reply.created_at) }}</span>
                </div>
                <p class="comment__content">{{ reply.content }}</p>
                <div class="comment__actions">
                  <button type="button" class="action" :class="{ 'is-active': reply.liked }" @click="toggleLike(reply)">
                    <icon :name="reply.liked ? 'i-carbon:thumbs-up-filled' : 'i-carbon:thumbs-up'" />
                    <span v-if="reply.likes">{{ reply.likes }}</span>
                  </button>
                  <button type="button" class="action" @click="startReply(comment)">
                    <icon name="i-carbon:reply" />
                    <span>{{ $t('comment.reply') }}</span>
                  </button>
                  <button v-if="reply.mine" type="button" class="action" @click="removeComment(reply)">
                    <icon name="i-carbon:trash-can" />
                    <span>{{ $t('comment.delete') }}</span>
                  </button>
                </div>
              </div>
            </li>
          </ul>
        </div>
      </li>
    </ul>

    <el-empty v-else-if="!loading" :description="$t('comment.empty')" :image-size="80" />

    <div v-if="hasMore" class="comments__more">
      <el-button text :loading="loading" @click="loadComments(page + 1)">
        {{ $t('comment.more') }}
      </el-button>
    </div>
  </section>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from 'element-plus'
import { useAuth } from '~/composables/useAuth'

interface CommentAuthor {
  id: number
  name: string
  avatar_url: string | null
}

interface CommentItem {
  id: number
  content: string
  created_at: string
  likes: number
  liked: boolean
  mine: boolean
  author: CommentAuthor
  replies: CommentItem[]
}

const props = defineProps<{ noteId: number }>()

const { isLoggedIn, user, authHeaders } = useAuth()
const { t } = useI18n()
const route = useRoute()
const localePath = useLocalePath()

const comments = ref<CommentItem[]>([])
const total = ref(0)
const page = ref(1)
const hasMore = ref(false)
const loading = ref(false)

// 默认按热度，和 B 站一致
const sort = ref<'hot' | 'time'>('hot')
const sortOptions = computed(() => [
  { label: t('comment.sortHot'), value: 'hot' },
  { label: t('comment.sortTime'), value: 'time' },
])

const draft = ref('')
const replyTo = ref<number | null>(null)
const replyDraft = ref('')
const submitting = ref(false)

const myInitial = computed(() => (user.value?.name || '?').slice(0, 1))

/** 未登录时统一跳登录页，登录后回到当前内容 */
function requireLogin() {
  if (isLoggedIn.value) return true

  navigateTo(localePath({ path: '/login', query: { redirect: route.fullPath } }))
  return false
}

function handleFocus() {
  if (!isLoggedIn.value) requireLogin()
}

async function loadComments(pageNo = 1) {
  loading.value = true
  try {
    const result = await $fetch<{
      items: CommentItem[]
      meta: { page: number, total_pages: number }
      total: number
    }>(`/notes/${props.noteId}/comments`, {
      baseURL: useApiBase(),
      headers: authHeaders(),
      query: { page: pageNo, sort: sort.value },
    })

    comments.value = pageNo === 1 ? result.items : [...comments.value, ...result.items]
    total.value = result.total
    page.value = pageNo
    hasMore.value = result.meta.page < result.meta.total_pages
  } finally {
    loading.value = false
  }
}

function reload() {
  loadComments(1)
}

async function submitComment(parent?: CommentItem) {
  if (!requireLogin()) return
  const content = (parent ? replyDraft.value : draft.value).trim()
  if (!content) return

  submitting.value = true
  try {
    const created = await $fetch<CommentItem>(`/notes/${props.noteId}/comments`, {
      baseURL: useApiBase(),
      method: 'POST',
      headers: authHeaders(),
      body: { content, parent_id: parent?.id },
    })

    if (parent) {
      const target = comments.value.find((item) => item.id === parent.id)
      target?.replies.push(created)
      replyDraft.value = ''
      replyTo.value = null
    } else {
      comments.value.unshift(created)
      draft.value = ''
    }
    total.value += 1
  } catch (err: any) {
    ElMessage.error(err?.data?.error || t('comment.failed'))
  } finally {
    submitting.value = false
  }
}

function startReply(comment: CommentItem) {
  if (!requireLogin()) return
  replyTo.value = comment.id
  replyDraft.value = ''
}

function cancelReply() {
  replyTo.value = null
  replyDraft.value = ''
}

async function toggleLike(comment: CommentItem) {
  if (!requireLogin()) return

  const unliking = comment.liked
  try {
    const result = await $fetch<{ liked: boolean, likes: number }>(
      `/comments/${comment.id}/${unliking ? 'unlike' : 'like'}`,
      {
        baseURL: useApiBase(),
        method: unliking ? 'DELETE' : 'POST',
        headers: authHeaders(),
      },
    )
    comment.liked = result.liked
    comment.likes = result.likes
  } catch {
    // 失败保持原状态，下次刷新会同步
  }
}

async function removeComment(comment: CommentItem) {
  try {
    await ElMessageBox.confirm(t('comment.deleteConfirm'), t('comment.delete'), {
      confirmButtonText: t('comment.delete'),
      cancelButtonText: t('comment.cancel'),
      type: 'warning',
    })
  } catch {
    return
  }

  try {
    await $fetch(`/comments/${comment.id}`, {
      baseURL: useApiBase(),
      method: 'DELETE',
      headers: authHeaders(),
    })

    comments.value = comments.value
      .filter((item) => item.id !== comment.id)
      .map((item) => ({ ...item, replies: item.replies.filter((reply) => reply.id !== comment.id) }))
    total.value = Math.max(0, total.value - 1)
  } catch (err: any) {
    ElMessage.error(err?.data?.error || t('comment.failed'))
  }
}

/** 相对时间：刚刚 / N 分钟前 / N 小时前 / N 天前 / 具体日期 */
function formatTime(value: string) {
  const time = new Date(value).getTime()
  const diff = Date.now() - time
  const minute = 60 * 1000
  const hour = 60 * minute
  const day = 24 * hour

  if (diff < minute) return t('time.justNow')
  if (diff < hour) return t('time.minutesAgo', { count: Math.floor(diff / minute) })
  if (diff < day) return t('time.hoursAgo', { count: Math.floor(diff / hour) })
  if (diff < 7 * day) return t('time.daysAgo', { count: Math.floor(diff / day) })

  return new Date(value).toLocaleDateString()
}

onMounted(() => loadComments(1))
</script>

<style scoped>
.comments {
  margin-top: 36px;
  padding-top: 24px;
  border-top: 1px solid var(--c-line);
}

.comments__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 18px;
}

.comments__title {
  margin: 0;
  color: var(--c-ink-1);
  font-size: 17px;
  font-weight: 600;
}

.comments__count {
  margin-left: 6px;
  color: var(--c-ink-3);
  font-size: 13px;
  font-weight: 400;
}

/* 发布框：头像 + 文本域 */
.editor {
  display: flex;
  gap: 12px;
  margin-bottom: 24px;
}

.editor__avatar {
  flex: none;
  background: var(--c-brand-gradient);
  color: #fff;
  font-size: 14px;
}

.editor__body {
  flex: 1;
  min-width: 0;
}

.editor__body :deep(.el-textarea__inner) {
  border-radius: 12px;
  background: var(--c-surface);
  box-shadow: 0 0 0 1px var(--c-line) inset;
  font-size: 13px;
  line-height: 1.7;
}

.editor__body :deep(.el-textarea__inner:focus) {
  background: var(--c-card);
  box-shadow: 0 0 0 1px var(--el-color-primary) inset;
}

.editor__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 8px;
}

.editor__hint {
  color: var(--c-ink-3);
  font-size: 11px;
}

/* 评论列表 */
.comment-list,
.reply-list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.comment {
  display: flex;
  gap: 12px;
  padding: 16px 0;
  border-bottom: 1px solid var(--c-line);
}

.comment:last-child {
  border-bottom: none;
}

.comment__avatar {
  flex: none;
  background: var(--c-surface);
  color: var(--c-ink-2);
  font-size: 14px;
}

.comment__main {
  flex: 1;
  min-width: 0;
}

.comment__meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
}

.comment__name {
  color: var(--c-ink-2);
  font-size: 13px;
  font-weight: 600;
}

.comment__floor,
.comment__time {
  color: var(--c-ink-3);
  font-size: 11px;
}

.comment__content {
  margin: 0 0 8px;
  color: var(--c-ink-1);
  font-size: 14px;
  line-height: 1.75;
  word-break: break-word;
  white-space: pre-wrap;
}

.comment__actions {
  display: flex;
  align-items: center;
  gap: 16px;
}

/* 操作按钮：纯图标 + 数字，hover 主色，与 B 站评论区一致 */
.action {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--c-ink-3);
  font-size: 12px;
  cursor: pointer;
  transition: color 0.15s ease;
}

.action:hover,
.action.is-active {
  color: var(--el-color-primary);
}

.action :deep(> div) {
  font-size: 14px;
}

/* 回复输入 */
.reply-editor {
  margin: 10px 0 4px;
}

.reply-editor :deep(.el-textarea__inner) {
  border-radius: 10px;
  background: var(--c-surface);
  box-shadow: 0 0 0 1px var(--c-line) inset;
  font-size: 13px;
}

.reply-editor__actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 6px;
}

/* 楼中楼：浅底缩进块 */
.reply-list {
  margin-top: 12px;
  padding: 10px 14px;
  border-radius: 12px;
  background: var(--c-surface);
}

.reply {
  display: flex;
  gap: 10px;
  padding: 8px 0;
}

.reply + .reply {
  border-top: 1px dashed var(--c-line);
}

.reply__avatar {
  flex: none;
  background: var(--c-card);
  color: var(--c-ink-2);
  font-size: 11px;
}

.reply__main {
  flex: 1;
  min-width: 0;
}

.reply__at {
  color: var(--el-color-primary);
  font-size: 11px;
}

.comments__more {
  display: flex;
  justify-content: center;
  margin-top: 14px;
}
</style>
