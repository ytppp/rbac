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

    <section v-else-if="notes.length" class="waterfall">
      <NoteCard v-for="note in notes" :key="note.id" :note="note" />
    </section>

    <p v-else-if="pending" class="empty">加载中…</p>

    <p v-else class="empty">没有找到相关内容，换个关键词试试</p>

    <!-- 无限下拉的「哨兵」：它一滚进视口附近，就自动去加载下一页 -->
    <div ref="sentinel" class="feed-sentinel">
      <template v-if="notes.length">
        <span v-if="pending">正在加载更多…</span>
        <span v-else-if="!hasMore">已经到底啦</span>
      </template>
    </div>
  </main>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import NoteCard from '~/components/NoteCard.vue'
import { useDebouncedRef, useFeed } from '~/composables/useFeed'
import { useNotesFeed } from '~/composables/useNotes'

const { keyword, channel } = useFeed()
// 搜索词防抖，避免输入过程中每敲一个字都请求一次
const debouncedKeyword = useDebouncedRef(keyword, 300)

const { notes, channels, pending, error, hasMore, loadMore } = await useNotesFeed(channel, debouncedKeyword)

// IntersectionObserver 是浏览器原生的「元素是否进入视口」观察器：
// 比监听 scroll 事件更省性能，且能直接判断哨兵位置。
const sentinel = ref<HTMLElement | null>(null)
let observer: IntersectionObserver | null = null

onMounted(() => {
  if (!sentinel.value) return

  observer = new IntersectionObserver(
    (entries) => {
      // 哨兵进入视口（提前 400px 触发，滚动手感更顺）就加载下一页
      if (entries.some((entry) => entry.isIntersecting)) loadMore()
    },
    { rootMargin: '400px 0px' }
  )
  observer.observe(sentinel.value)
})

// 组件卸载时断开观察，避免内存泄漏
onBeforeUnmount(() => observer?.disconnect())

/** 切频道时回到顶部，避免停在上一屏的滚动位置 */
function handleChannel(item: string) {
  channel.value = item
  window.scrollTo({ top: 0, behavior: 'smooth' })
}
</script>
