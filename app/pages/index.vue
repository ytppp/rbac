<template>
  <main class="feed">
    <nav class="channel-bar">
      <div class="channel-inner">
        <button
          v-for="item in channels"
          :key="item"
          class="channel"
          :class="{ 'is-active': item === channel }"
          type="button"
          @click="handleChannel(item)"
        >
          {{ item }}
        </button>
      </div>
    </nav>

    <p v-if="error" class="empty">内容加载失败，请确认 api 服务已启动</p>

    <section v-else-if="notes.length" class="waterfall" :class="{ 'is-pending': pending }">
      <NoteCard v-for="note in notes" :key="note.id" :note="note" />
    </section>

    <p v-else-if="pending" class="empty">加载中…</p>

    <p v-else class="empty">没有找到相关内容，换个关键词试试</p>
  </main>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import NoteCard from '~/components/NoteCard.vue'
import { useDebouncedRef, useFeed } from '~/composables/useFeed'
import { useNotes } from '~/composables/useNotes'

const { keyword, channel } = useFeed()
// 搜索词防抖，避免输入过程中每敲一个字都请求一次
const debouncedKeyword = useDebouncedRef(keyword, 300)

const { data, pending, error } = await useNotes(channel, debouncedKeyword)

const notes = computed(() => data.value?.items ?? [])
const channels = computed(() => data.value?.channels ?? [])

/** 切频道时回到顶部，避免停在上一屏的滚动位置 */
function handleChannel(item: string) {
  channel.value = item
  window.scrollTo({ top: 0, behavior: 'smooth' })
}
</script>
