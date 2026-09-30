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
import { computed, ref } from 'vue'
import type { Note } from '~/composables/useNotes'
import { formatLikes } from '~/utils/format'

const props = defineProps<{ note: Note }>()

// 点赞目前只有前端状态，还没有对应的写接口
const liked = ref(false)

const likeText = computed(() => formatLikes(props.note.likes + (liked.value ? 1 : 0)))

function toggleLike() {
  liked.value = !liked.value
}
</script>
