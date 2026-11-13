<template>
  <!-- 瀑布流式网格：复用在个人中心与作者主页 -->
  <div class="note-grid">
    <note-card v-for="note in notes" :key="note.id" :note="note" />
  </div>
</template>

<script setup lang="ts">
import type { Note } from '~/composables/useNotes'

defineProps<{ notes: Note[] }>()
</script>

<style scoped>
.note-grid {
  columns: 2;
  column-gap: 16px;
}

.note-grid > * {
  display: block;
  margin-bottom: 16px;
  break-inside: avoid;
}

@media (min-width: 768px) {
  .note-grid {
    columns: 3;
  }
}

@media (min-width: 1024px) {
  .note-grid {
    columns: 4;
  }
}
</style>
