<template>
  <el-card
    class="note-card cursor-pointer"
    shadow="never"
    :body-style="{ padding: '0' }"
    @click="goDetail"
  >
    <div class="note-cover" :style="{ aspectRatio: String(note.cover_ratio) }">
      <el-image class="note-cover__img" :src="note.cover" :alt="note.title" fit="cover" />
      <span class="note-cover__shade" />
      <span class="note-cover__channel">{{ note.channel }}</span>
    </div>

    <div class="px-16px pb-15px pt-13px">
      <h3 class="mt-0 mb-10px line-clamp-2 text-14px font-600 leading-[1.55] tracking-[0.01em] text-ink-1">{{ note.title }}</h3>

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

        <el-button link class="note-like" :class="{ 'is-liked': liked }" :loading="submitting" @click.stop="toggleLike">
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

/** 点击卡片进入详情页 */
function goDetail() {
  navigateTo(`/explore/${props.note.id}`)
}

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
/* 卡片外壳：暖白卡片 + 细边框，hover 时轻微上浮并让封面图放大 */
.note-card {
  border: 1px solid var(--c-line);
  border-radius: 18px;
  overflow: hidden;
  background: var(--c-card);
  box-shadow: 0 2px 6px var(--c-shadow);
  transition: transform 0.25s ease, box-shadow 0.25s ease, border-color 0.25s ease;
}
.note-card:hover {
  transform: translateY(-5px);
  border-color: var(--el-color-primary-light-7);
  box-shadow: 0 18px 38px var(--c-shadow);
}

/* 封面：底部渐变保证频道标签可读，图片在 hover 时缓慢放大 */
.note-cover {
  position: relative;
  width: 100%;
  min-height: 120px;
  overflow: hidden;
  background: var(--c-surface);
}
.note-cover__img {
  display: block;
  width: 100%;
  height: 100%;
  background: var(--c-surface);
}
.note-cover__img :deep(.el-image__inner) {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.5s ease;
}
.note-card:hover .note-cover__img :deep(.el-image__inner) {
  transform: scale(1.05);
}
.note-cover__shade {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    180deg,
    rgba(8, 30, 32, 0.26) 0%,
    rgba(8, 30, 32, 0) 34%,
    rgba(8, 30, 32, 0) 68%,
    rgba(8, 30, 32, 0.2) 100%
  );
  pointer-events: none;
}
.note-cover__channel {
  position: absolute;
  top: 10px;
  left: 10px;
  padding: 2px 9px;
  border-radius: 999px;
  background: var(--c-glass);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  color: var(--c-ink-1);
  font-size: 11px;
  font-weight: 500;
}

.note-avatar {
  font-size: 11px;
}

/* 点赞按钮：未赞为灰，已赞 / 悬停为主色 */
.note-card .note-like {
  color: var(--c-ink-2);
  font-size: 12px;
}
.note-card .note-like:hover {
  color: var(--el-color-primary);
}
.note-card .note-like.is-liked,
.note-card .note-like.is-liked:hover {
  color: var(--el-color-primary);
}
</style>
