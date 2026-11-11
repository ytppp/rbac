<template>
  <div class="flex flex-col gap-5">
    <!-- 旅行主题横幅：一张海岸公路图 + 深色渐变，保证文字可读 -->
    <section class="travel-hero">
      <el-image class="travel-hero__img" :src="HERO_IMAGE" alt="海岸公路旅行风景" fit="cover" />
      <div class="travel-hero__shade" />
      <div class="travel-hero__content">
        <p class="travel-hero__eyebrow">TRAVEL JOURNAL</p>
        <h1 class="travel-hero__title">把每一次出发，收藏成故事</h1>
        <p class="travel-hero__desc">地图路线、沿途照片与旅行手记，都在这里。</p>
      </div>
      <div class="travel-hero__tags">
        <el-tag class="travel-hero__tag" round effect="plain">
          <icon name="i-carbon:map" /> 路线地图
        </el-tag>
        <el-tag class="travel-hero__tag" round effect="plain">
          <icon name="i-carbon:camera" /> 沿途相册
        </el-tag>
      </div>
    </section>

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
  </div>
</template>

<script setup lang="ts">
import { defineAsyncComponent, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import type { Note } from '~/composables/useNotes'
import { useDebouncedRef, useFeed } from '~/composables/useFeed'
import { useNotesFeed } from '~/composables/useNotes'

/** 首页横幅图：海岸公路，和全站的青 / 沙 / 珊瑚配色一致 */
const HERO_IMAGE =
  'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=winding%20coastal%20road%20along%20turquoise%20ocean%2C%20golden%20hour%2C%20green%20mountains%2C%20cinematic%20travel%20photography%2C%20warm%20sunlight%2C%20no%20text&image_size=landscape_16_9'

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

<style scoped>
/* 首页旅行横幅：固定高度，图片铺满，左侧压深色渐变承载文字 */
.travel-hero {
  position: relative;
  height: 190px;
  overflow: hidden;
  border-radius: 24px;
  background: var(--el-color-primary-dark-2);
  box-shadow: 0 18px 40px var(--c-shadow);
}

.travel-hero__img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.travel-hero__img :deep(.el-image__inner) {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.travel-hero__shade {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    90deg,
    rgba(7, 38, 42, 0.82) 0%,
    rgba(7, 38, 42, 0.46) 46%,
    rgba(7, 38, 42, 0.08) 100%
  );
}

.travel-hero__content {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  height: 100%;
  padding: 0 32px;
  color: #fff;
}

.travel-hero__eyebrow {
  margin: 0 0 8px;
  color: rgba(255, 255, 255, 0.72);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.24em;
}

.travel-hero__title {
  margin: 0;
  font-size: 26px;
  font-weight: 600;
  letter-spacing: 0.02em;
  line-height: 1.35;
}

.travel-hero__desc {
  margin: 8px 0 0;
  color: rgba(255, 255, 255, 0.82);
  font-size: 13px;
}

.travel-hero__tags {
  position: absolute;
  right: 20px;
  bottom: 18px;
  z-index: 1;
  display: flex;
  gap: 8px;
}

/* 横幅标签：用 el-tag 承载，覆盖成白色毛玻璃胶囊 */
.travel-hero__tags .travel-hero__tag {
  height: auto;
  padding: 5px 11px;
  border-radius: 999px;
  font-size: 12px;
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  --el-tag-text-color: #fff;
  --el-tag-bg-color: rgba(255, 255, 255, 0.16);
  --el-tag-border-color: rgba(255, 255, 255, 0.24);
}

.travel-hero__tag :deep(.el-tag__content) {
  display: inline-flex;
  align-items: center;
  gap: 5px;
}

@media (max-width: 768px) {
  .travel-hero {
    height: 160px;
    border-radius: 20px;
  }

  .travel-hero__content {
    padding: 0 20px;
  }

  .travel-hero__title {
    font-size: 20px;
  }

  .travel-hero__desc {
    font-size: 12px;
  }

  .travel-hero__tags {
    display: none;
  }
}
</style>
