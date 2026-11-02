<template>
  <div class="isolate">
    <app-header />
    <main class="flex-x-center pt-[82px] pb-40px">
      <div class="content-width flex gap-4">
        <div class="min-w-0 flex-1">
          <slot />
        </div>
        <!-- 版权、备案等信息：桌面端固定在右侧栏，滚动时跟随视口停靠；移动端改在列表末尾展示（见首页） -->
        <site-info
          v-if="!hideSiteInfo"
          class="hidden w-52 flex-none lg:block lg:self-start lg:sticky"
          :class="headerShown ? 'lg:top-66px' : 'lg:top-0'"
        />
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
// 顶栏可见状态：顶栏隐藏时右栏贴到视口顶部，避免留下 66px 空白
const headerShown = useState('header-shown', () => true)
const route = useRoute()
// 页面自己把版权信息放在内容底部时（如地图详情页），隐藏右侧固定栏
const hideSiteInfo = computed(() => Boolean(route.meta.hideSiteInfo))
</script>
