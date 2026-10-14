<template>
  <article class="note-card">
    <div class="note-cover" :style="{ aspectRatio: String(note.cover_ratio) }">
      <img class="note-image" :src="note.cover" :alt="note.title" loading="lazy" />
    </div>

    <div class="note-body">
      <h3 class="note-title">{{ note.title }}</h3>

      <div class="note-meta">
        <span class="note-author">
          <span class="note-avatar" :style="{ backgroundColor: note.avatar_color }">
            {{ note.author.slice(0, 1) }}
          </span>
          <span class="note-author-name">{{ note.author }}</span>
        </span>

        <button
          class="note-like"
          :class="{ 'is-liked': liked }"
          type="button"
          :disabled="submitting"
          @click="toggleLike"
        >
          <svg class="like-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path
              d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
            />
          </svg>
          <span>{{ likeText }}</span>
        </button>
      </div>
    </div>
  </article>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { Note } from '~/composables/useNotes'
import { useAuth } from '~/composables/useAuth'
import { formatLikes } from '~/utils/format'

const props = defineProps<{ note: Note }>()

const route = useRoute()
const { isLoggedIn, authHeaders } = useAuth()

// 本地状态：从后端返回的数据初始化，点赞后本地即时更新，避免整页刷新
const liked = ref(props.note.liked)
const likes = ref(props.note.likes)
const submitting = ref(false)

// 列表重新拉取时，同一张卡片可能被复用，这里同步一下最新的服务端状态
watch(
  () => props.note,
  (note) => {
    liked.value = note.liked
    likes.value = note.likes
  }
)

const likeText = computed(() => formatLikes(likes.value))

async function toggleLike() {
  if (submitting.value) return

  // 未登录不能点赞：引导去登录，登录后回到当前页
  if (!isLoggedIn.value) {
    await navigateTo({ path: '/login', query: { redirect: route.fullPath } })
    return
  }

  submitting.value = true
  try {
    const baseURL = useApiBase()
    // 已赞 -> 取消赞（DELETE /unlike）；未赞 -> 点赞（POST /like）
    const unliking = liked.value

    const result = await $fetch<{ liked: boolean; likes: number }>(
      `/notes/${props.note.id}/${unliking ? 'unlike' : 'like'}`,
      {
        baseURL,
        method: unliking ? 'DELETE' : 'POST',
        headers: authHeaders()
      }
    )

    liked.value = result.liked
    likes.value = result.likes
  } catch {
    // 请求失败（比如 token 过期）时不改状态，保持和服务器一致
  } finally {
    submitting.value = false
  }
}
</script>
