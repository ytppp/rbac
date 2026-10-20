<template>
  <nav
    class="channel-bar sticky z-15 border-b border-line bg-[rgba(245,245,245,0.94)] [backdrop-filter:saturate(180%)_blur(12px)] lg:hidden dark:bg-[rgba(10,10,10,0.94)]"
    :class="headerShown ? 'top-66px' : 'top-0'"
  >
    <el-tabs v-model="channel" class="channel-tabs" @tab-change="scrollToTop">
      <el-tab-pane v-for="item in channels" :key="item" :label="item" :name="item" />
    </el-tabs>
  </nav>
  <nav class="channel-side hidden lg:sticky lg:block lg:w-40 lg:flex-none lg:self-start lg:bg-page lg:pt-4" :class="headerShown ? 'lg:top-66px' : 'lg:top-0'">
    <card :border="false">
      <el-menu :default-active="channel" class="channel-menu" @select="handleSelect">
        <el-menu-item v-for="item in channels" :key="item" :index="item">{{ item }}</el-menu-item>
      </el-menu>
    </card>
  </nav>
</template>

<script setup lang="ts">
import { useFeed } from '~/composables/useFeed'

defineProps<{ channels: string[] }>()

// 顶栏可见状态：顶栏隐藏时左侧导航贴到视口顶部，避免留下 66px 空白
const headerShown = useState('header-shown', () => true)
const { channel } = useFeed()

/** 切频道时回到顶部，避免停在上一屏的滚动位置 */
function scrollToTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

/** el-menu 的选中回调：tab 那侧由 v-model 直接同步，这里需要手动写回 */
function handleSelect(name: string) {
  channel.value = name
  scrollToTop()
}
</script>

<style scoped>
/* 频道栏：复用 el-tabs，隐藏 EP 自带的灰色底边与外层滚动箭头，改由外层 nav 提供分割线 */
.channel-tabs :deep(.el-tabs__header) {
  margin: 0;
}
.channel-tabs :deep(.el-tabs__nav-wrap) {
  padding: 0 16px;
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

/* 左侧频道导航：去掉 el-menu 默认的右边框与背景，选中项用一个浅底高亮 */
.channel-menu {
  border-right: none;
  --el-menu-bg-color: transparent;
  --el-menu-hover-bg-color: var(--c-surface);
  --el-menu-item-height: auto;
  --el-menu-active-color: var(--el-color-primary);
}
.channel-menu :deep(.el-menu-item) {
  @apply flex-y-center rounded-8px px-3 py-2 text-14px;
  height: auto;
  line-height: 1.5;
  margin-bottom: 2px;
}
.channel-menu :deep(.el-menu-item.is-active) {
  background-color: var(--el-color-primary-light-9);
  font-weight: 500;
}
</style>
