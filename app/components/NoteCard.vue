<template>
  <article
    class="mb-16px cursor-pointer break-inside-avoid overflow-hidden rounded-12px bg-card transition-[transform,box-shadow] duration-180 hover:-translate-y-3px hover:shadow-[0_8px_24px_rgba(0,0,0,0.08)]"
  >
    <div
      class="min-h-120px w-full overflow-hidden bg-[#efefef]"
      :style="{ aspectRatio: String(note.cover_ratio) }"
    >
      <img class="block h-full w-full object-cover" :src="note.cover" :alt="note.title" loading="lazy" />
    </div>

    <div class="px-12px pb-12px pt-10px">
      <h3 class="mt-0 mb-8px line-clamp-2 text-14px font-500 leading-[1.45]">{{ note.title }}</h3>

      <div class="flex items-center justify-between gap-8px">
        <span class="flex min-w-0 items-center gap-6px">
          <!-- 有作者头像显示头像，没有则维持原来的「首字 + 底色」 -->
          <span
            class="inline-flex h-20px w-20px flex-none items-center justify-center overflow-hidden rounded-full text-11px text-white"
            :style="note.author_avatar ? undefined : { backgroundColor: note.avatar_color }"
          >
            <img
              v-if="note.author_avatar"
              class="h-full w-full object-cover"
              :src="note.author_avatar"
              :alt="note.author"
            />
            <template v-else>{{ note.author.slice(0, 1) }}</template>
          </span>
          <span class="overflow-hidden text-12px text-ellipsis whitespace-nowrap text-ink-2">{{ note.author }}</span>
        </span>

        <button
          class="inline-flex flex-none cursor-pointer items-center gap-3px border-0 bg-none p-0 text-12px transition-colors duration-180"
          :class="liked ? 'text-brand' : 'text-ink-2 hover:text-brand'"
          type="button"
          :disabled="submitting"
          @click="toggleLike"
        >
          <svg
            class="h-15px w-15px stroke-current stroke-[1.9] [stroke-linejoin:round]"
            :class="liked ? 'fill-current' : 'fill-none'"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
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
