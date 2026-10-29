<template>
  <el-card
    class="note-card cursor-pointer"
    shadow="hover"
    :body-style="{ padding: '0' }"
  >
    <div
      class="min-h-120px w-full overflow-hidden bg-surface"
      :style="{ aspectRatio: String(note.cover_ratio) }"
    >
      <img class="block h-full w-full object-cover" :src="note.cover" :alt="note.title" loading="lazy" />
    </div>

    <div class="px-14px pb-14px pt-12px">
      <h3 class="mt-0 mb-10px line-clamp-2 text-14px font-500 leading-[1.55] text-ink-1">{{ note.title }}</h3>

      <div class="flex items-center justify-between gap-8px">
        <span class="flex min-w-0 items-center gap-6px">
          <!-- 有作者头像显示头像，没有则维持原来的「首字 + 底色」 -->
          <el-avatar
            class="note-avatar"
            :size="20"
            :src="note.author_avatar || undefined"
            :style="note.author_avatar ? undefined : { backgroundColor: note.avatar_color }"
          >
            {{ note.author.slice(0, 1) }}
          </el-avatar>
          <span class="overflow-hidden text-12px text-ellipsis whitespace-nowrap text-ink-2">{{ note.author }}</span>
        </span>

        <el-button link class="note-like" :class="{ 'is-liked': liked }" :loading="submitting" @click="toggleLike">
          <icon :name="liked ? 'i-carbon:favorite-filled' : 'i-carbon:favorite'" />
          <span class="ml-3px">{{ likeText }}</span>
        </el-button>
      </div>
    </div>
  </el-card>
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

<style scoped>
/* 卡片外壳：去掉 el-card 默认边框，改为常驻轻阴影 + 柔和圆角，hover 时轻微上浮提亮 */
.note-card {
  border: none;
  border-radius: 14px;
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.note-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.1);
}

.note-avatar {
  font-size: 11px;
}

/* 点赞按钮：未赞为灰，已赞 / 悬停为品牌红 */
.note-card .note-like {
  color: var(--c-ink-2);
  font-size: 12px;
}
.note-card .note-like:hover {
  color: #ff2e4d;
}
.note-card .note-like.is-liked,
.note-card .note-like.is-liked:hover {
  color: #ff2e4d;
}
</style>
