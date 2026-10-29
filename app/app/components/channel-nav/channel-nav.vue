<template>
  <!-- 窄屏：吸顶在顶栏下方的横向频道栏（统一 el-menu，mode=horizontal 横向滚动） -->
  <nav
    class="channel-bar sticky z-15 border-b border-line bg-[rgba(245,245,245,0.94)] [backdrop-filter:saturate(180%)_blur(12px)] lg:hidden dark:bg-[rgba(10,10,10,0.94)]"
    :class="headerShown ? 'top-66px' : 'top-0'"
  >
    <el-menu
      mode="horizontal"
      class="channel-bar-menu"
      :default-active="channel"
      @select="handleSelect"
    >
      <el-menu-item v-for="item in channels" :key="item" :index="item">{{ item }}</el-menu-item>
    </el-menu>
  </nav>

  <!-- 宽屏：左侧竖向频道导航 -->
  <nav
    class="channel-side hidden lg:sticky lg:block lg:w-44 lg:flex-none lg:self-start lg:pt-4"
    :class="headerShown ? 'lg:top-66px' : 'lg:top-0'"
  >
    <div class="mb-2 px-3 text-12px font-500 uppercase tracking-[0.5px] text-ink-3">频道</div>
    <card :border="true" shadow="hover" body-class="!p-2">
      <el-menu :default-active="channel" class="channel-menu" @select="handleSelect">
        <el-menu-item v-for="item in channels" :key="item" :index="item">{{ item }}</el-menu-item>
      </el-menu>
    </card>
  </nav>
</template>

<script setup lang="ts">
import { useFeed } from '~/composables/useFeed'

defineProps<{ channels: string[] }>()

// 顶栏可见状态：顶栏隐藏时频道栏贴到视口顶部，避免留下 66px 空白
const headerShown = useState('header-shown', () => true)
const { channel } = useFeed()

/** 切频道时回到顶部，避免停在上一屏的滚动位置 */
function scrollToTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

/** el-menu 的选中回调：横向/竖向两套菜单都走这里，选完写回 channel 并回顶 */
function handleSelect(name: string) {
  channel.value = name
  scrollToTop()
}
</script>

<style scoped>
/* 窄屏横向频道栏：去掉 el-menu 默认的底部边框线，转成 flex 横向滚动并隐藏滚动条 */
.channel-bar-menu {
  border-bottom: none;
  --el-menu-bg-color: transparent;
  --el-menu-hover-bg-color: var(--c-surface);
  --el-menu-active-color: var(--el-color-primary);
}
.channel-bar-menu :deep(.el-menu--horizontal) {
  display: flex;
  align-items: center;
  padding: 0 16px;
  width: 100%;
  overflow-x: auto;
  scrollbar-width: none;
  border-bottom: none;
}
.channel-bar-menu :deep(.el-menu--horizontal::-webkit-scrollbar) {
  display: none;
}
.channel-bar-menu :deep(.el-menu-item) {
  @apply flex-y-center text-14px;
  height: 56px;
  line-height: 56px;
  margin: 0 18px;
}
.channel-bar-menu :deep(.el-menu-item:first-child) {
  margin-left: 0;
}

/* 左侧竖向频道导航：去掉 el-menu 默认的右边框与背景，选中项用一个浅底高亮 */
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
  transition: background-color 0.15s ease, color 0.15s ease;
}
.channel-menu :deep(.el-menu-item.is-active) {
  background-color: var(--el-color-primary-light-9);
  font-weight: 500;
  color: var(--el-color-primary);
}
</style>