<template>
  <main class="flex flex-col gap-4 lg:flex-row lg:gap-6">
    <channel-nav :channels="channels" />
    <div class="min-w-0 flex-1">
      <el-alert
        v-if="error"
        class="mx-auto mt-60px max-w-[560px]"
        type="error"
        title="内容加载失败，请确认 api 服务已启动"
        :closable="false"
        show-icon
      />
      <section v-else-if="notes.length">
        <!-- 瀑布流异步懒加载且只在客户端渲染：加载完成前先用骨架屏占位，避免首屏空白 -->
        <div v-if="!waterfallReady" class="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
          <el-skeleton v-for="i in 8" :key="i" animated>
            <template #template>
              <el-skeleton-item variant="image" class="!h-160px !w-full !rounded-8px" />
              <div class="mt-3 space-y-2">
                <el-skeleton-item variant="text" class="!w-90%" />
                <el-skeleton-item variant="text" class="!w-60%" />
              </div>
            </template>
          </el-skeleton>
        </div>
        <client-only>
          <component
            :is="Waterfall"
            :list="notes"
            row-key="id"
            img-selector="cover"
            background-color="transparent"
            :has-around-gutter="false"
            :gutter="16"
            :breakpoints="waterfallBreakpoints"
            :animation-cancel="true"
            @after-render="handleAfterRender"
          >
            <template #default="{ item }">
              <note-card :note="item as Note" />
            </template>
          </component>
        </client-only>
      </section>

      <div v-else-if="pending" class="flex-y-center justify-center gap-2 py-120px text-14px text-ink-3">
        <el-icon class="is-loading" :size="16"><icon name="i-carbon:circle-dash" /></el-icon>
        <span>加载中…</span>
      </div>

      <div v-else class="py-80px">
        <el-empty description="没有找到相关内容，换个关键词试试" />
      </div>

      <!-- 无限下拉的「哨兵」：它一滚进视口附近，就自动去加载下一页 -->
      <div ref="sentinel" class="flex min-h-48px items-center justify-center gap-2 pb-6 text-13px text-ink-3">
        <template v-if="notes.length">
          <template v-if="pending">
            <el-icon class="is-loading" :size="14"><icon name="i-carbon:circle-dash" /></el-icon>
            <span>正在加载更多…</span>
          </template>
          <span v-else-if="!hasMore">~我是有底线的~</span>
        </template>
      </div>
      <site-info class="pt-6 lg:hidden" />
    </div>
  </main>
</template>

<script setup lang="ts">
import { defineAsyncComponent, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { Note } from '~/composables/useNotes'
import { useDebouncedRef, useFeed } from '~/composables/useFeed'
import { useNotesFeed } from '~/composables/useNotes'

// vue-waterfall-plugin-next 在模块顶层就访问了 document，参与 SSR 会直接报错，
// 因此改成惰性加载，并只在客户端（下面的 ClientOnly 内）渲染
const Waterfall = defineAsyncComponent(() => import('vue-waterfall-plugin-next').then((m) => m.Waterfall))

const { keyword, channel } = useFeed()
// 搜索词防抖，避免输入过程中每敲一个字都请求一次
const debouncedKeyword = useDebouncedRef(keyword, 300)

const { notes, channels, pending, error, hasMore, loadMore } = await useNotesFeed(channel, debouncedKeyword)

/**
 * 瀑布流分列规则：插件按「容器宽度」判断列数，而不是视口宽度，
 * 所以这里的阈值是视口断点减去页面左右 24px 内边距后的容器宽度，
 * 最终列数与原 columns 布局保持一致（5 / 4 / 3 / 2）。
 */
const waterfallBreakpoints = {
  720: { rowPerView: 2 },
  976: { rowPerView: 3 },
  1232: { rowPerView: 4 },
  1452: { rowPerView: 5 }
}

// IntersectionObserver 是浏览器原生的「元素是否进入视口」观察器：
// 比监听 scroll 事件更省性能，且能直接判断哨兵位置。
const sentinel = ref<HTMLElement | null>(null)
// 瀑布流首次排版完成前为 false，此时用骨架屏占位，避免空白
const waterfallReady = ref(false)
let observer: IntersectionObserver | null = null
let fallbackTimer: ReturnType<typeof setTimeout> | null = null

/** 瀑布流排版完成：关闭骨架屏，并挂上哨兵观察器 */
function handleAfterRender() {
  waterfallReady.value = true
  armSentinel()
}

/**
 * 挂上哨兵观察器。
 * 瀑布流组件首次排版完成前容器高度是 0，此时挂观察器会把哨兵误判成「已进入视口」，
 * 导致一进页面就多加载一页；所以等它派发 after-render（排版完成）后再挂。
 */
function armSentinel() {
  if (observer || !sentinel.value) return

  observer = new IntersectionObserver(
    (entries) => {
      // 哨兵进入视口（提前 400px 触发，滚动手感更顺）就加载下一页
      if (entries.some((entry) => entry.isIntersecting)) loadMore()
    },
    { rootMargin: '400px 0px' }
  )
  observer.observe(sentinel.value)
}

// 兜底：万一 after-render 没触发（例如插件异常），也保证哨兵观察器最终挂上
onMounted(() => {
  fallbackTimer = setTimeout(armSentinel, 1500)
})

// 切换频道会清空列表、瀑布流重新排版，先摘掉观察器避免误触发，等下次排版完成再挂
watch(
  () => notes.value.length,
  (len) => {
    if (!len) {
      observer?.disconnect()
      observer = null
      waterfallReady.value = false
    }
  }
)

// 组件卸载时断开观察，避免内存泄漏
onBeforeUnmount(() => {
  observer?.disconnect()
  if (fallbackTimer) clearTimeout(fallbackTimer)
})

</script>
