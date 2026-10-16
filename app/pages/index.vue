<template>
  <main>
    <nav class="sticky top-64px z-15 border-b border-line bg-[rgba(245,245,245,0.94)] [backdrop-filter:saturate(180%)_blur(12px)]">
      <div class="mx-auto max-w-[1500px] px-24px max-md:px-16px">
        <el-tabs v-model="channel" class="channel-tabs" @tab-change="handleChannelChange">
          <el-tab-pane v-for="item in channels" :key="item" :label="item" :name="item" />
        </el-tabs>
      </div>
    </nav>

    <el-alert
      v-if="error"
      class="mx-auto mt-80px max-w-[560px]"
      type="error"
      title="内容加载失败，请确认 api 服务已启动"
      :closable="false"
      show-icon
    />

    <section
      v-else-if="notes.length"
      class="mx-auto max-w-[1500px] columns-5 gap-16px px-24px pb-56px pt-16px max-xl:columns-4 max-lg:columns-3 max-md:columns-2 max-md:px-16px max-md:pb-40px max-md:pt-12px"
    >
      <NoteCard v-for="note in notes" :key="note.id" :note="note" />
    </section>

    <div v-else-if="pending" class="flex-y-center justify-center gap-2 px-24px py-120px text-14px text-ink-3">
      <el-icon class="is-loading" :size="16"><icon name="i-carbon:circle-dash" /></el-icon>
      <span>加载中…</span>
    </div>

    <div v-else class="py-80px">
      <el-empty description="没有找到相关内容，换个关键词试试" />
    </div>

    <!-- 无限下拉的「哨兵」：它一滚进视口附近，就自动去加载下一页 -->
    <div ref="sentinel" class="flex min-h-48px items-center justify-center gap-2 px-24px pb-24px text-13px text-ink-3">
      <template v-if="notes.length">
        <template v-if="pending">
          <el-icon class="is-loading" :size="14"><icon name="i-carbon:circle-dash" /></el-icon>
          <span>正在加载更多…</span>
        </template>
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
function handleChannelChange() {
  window.scrollTo({ top: 0, behavior: 'smooth' })
}
</script>

<style scoped>
/* 频道栏：复用 el-tabs，但把外观改回旧设计的红色小圆点下划线 */
.channel-tabs :deep(.el-tabs__header) {
  margin: 0;
}
/* 隐藏 EP 自带的灰色底边与外层滚动箭头占位，改由外层 nav 提供分割线 */
.channel-tabs :deep(.el-tabs__nav-wrap) {
  padding: 0;
}
.channel-tabs :deep(.el-tabs__nav-wrap.is-scrollable) {
  padding: 0;
}
.channel-tabs :deep(.el-tabs__nav-wrap::after) {
  display: none;
}
.channel-tabs :deep(.el-tabs__nav-next),
.channel-tabs :deep(.el-tabs__nav-prev) {
  display: none;
}
/* 频道过多时横向滚动，隐藏滚动条 */
.channel-tabs :deep(.el-tabs__nav-scroll) {
  overflow-x: auto;
  scrollbar-width: none;
}
.channel-tabs :deep(.el-tabs__nav-scroll::-webkit-scrollbar) {
  display: none;
}
/* 去掉默认的整条滑动条，改用激活项下方的小圆角线 */
.channel-tabs :deep(.el-tabs__active-bar) {
  display: none;
}
.channel-tabs :deep(.el-tabs__item) {
  @apply px-11px py-13px text-14px;
  height: auto;
  line-height: 1.4;
}
.channel-tabs :deep(.el-tabs__item.is-active) {
  @apply relative font-600;
}
.channel-tabs :deep(.el-tabs__item.is-active)::after {
  content: '';
  @apply absolute bottom-6px left-1/2 h-3px w-20px rounded-2px bg-brand;
  transform: translateX(-50%);
}
</style>
