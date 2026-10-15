<template>
  <main>
    <nav class="sticky top-64px z-15 border-b border-line bg-[rgba(245,245,245,0.94)] [backdrop-filter:saturate(180%)_blur(12px)]">
      <div class="mx-auto flex max-w-[1500px] gap-22px overflow-x-auto px-24px [scrollbar-width:none] max-md:px-16px [&::-webkit-scrollbar]:hidden">
        <button
          v-for="item in channels"
          :key="item"
          class="relative flex-none cursor-pointer border-0 bg-none py-13px text-14px transition-colors duration-180"
          :class="channelClass(item)"
          type="button"
          @click="handleChannel(item)"
        >
          {{ item }}
        </button>
      </div>
    </nav>

    <p v-if="error" class="px-24px py-120px text-center text-14px text-ink-3">内容加载失败，请确认 api 服务已启动</p>

    <section
      v-else-if="notes.length"
      class="mx-auto max-w-[1500px] columns-5 gap-16px px-24px pb-56px pt-16px max-xl:columns-4 max-lg:columns-3 max-md:columns-2 max-md:px-16px max-md:pb-40px max-md:pt-12px"
    >
      <NoteCard v-for="note in notes" :key="note.id" :note="note" />
    </section>

    <p v-else-if="pending" class="px-24px py-120px text-center text-14px text-ink-3">加载中…</p>

    <p v-else class="px-24px py-120px text-center text-14px text-ink-3">没有找到相关内容，换个关键词试试</p>

    <!-- 无限下拉的「哨兵」：它一滚进视口附近，就自动去加载下一页 -->
    <div ref="sentinel" class="flex min-h-48px items-center justify-center px-24px pb-24px text-13px text-ink-3">
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

// 选中频道：文字加深加粗，并用 ::after 画一小段品牌色下划线
const ACTIVE_CHANNEL_CLASS =
  "text-ink-1 font-600 after:content-[''] after:absolute after:bottom-6px after:left-1/2 after:h-3px after:w-20px after:rounded-2px after:bg-brand after:-translate-x-1/2"

function channelClass(item: string) {
  return item === channel.value ? ACTIVE_CHANNEL_CLASS : 'text-ink-2 hover:text-ink-1'
}

/** 切频道时回到顶部，避免停在上一屏的滚动位置 */
function handleChannel(item: string) {
  channel.value = item
  window.scrollTo({ top: 0, behavior: 'smooth' })
}
</script>
