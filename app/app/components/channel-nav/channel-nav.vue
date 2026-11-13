<template>
  <!-- 窄屏：吸顶在顶栏下方的横向频道栏（统一 el-menu，mode=horizontal 横向滚动） -->
  <nav
    class="channel-bar sticky z-15 lg:hidden"
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
    <div class="mb-2 px-3">
      <p class="travel-eyebrow m-0">{{ $t('channel.eyebrow') }}</p>
      <p class="m-0 mt-1 text-13px font-600 text-ink-1">{{ $t('channel.title') }}</p>
    </div>
    <card :border="true" shadow="never" class="channel-card" body-class="!p-2">
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
/* 窄屏横向频道栏：暖白毛玻璃 + 胶囊选中态 */
.channel-bar {
  background: var(--c-header-bg);
  backdrop-filter: saturate(180%) blur(12px);
  -webkit-backdrop-filter: saturate(180%) blur(12px);
  border-bottom: 1px solid var(--c-line);
}

.channel-bar-menu {
  border-bottom: none;
  --el-menu-bg-color: transparent;
  --el-menu-hover-bg-color: transparent;
  --el-menu-active-color: var(--el-color-primary);
}
.channel-bar-menu :deep(.el-menu--horizontal) {
  display: flex;
  align-items: center;
  padding: 0 12px;
  height: 54px;
  width: 100%;
  overflow-x: auto;
  scrollbar-width: none;
  border-bottom: none;
}
.channel-bar-menu :deep(.el-menu--horizontal::-webkit-scrollbar) {
  display: none;
}
.channel-bar-menu :deep(.el-menu-item) {
  @apply flex-y-center text-13px;
  height: 34px;
  line-height: 34px;
  margin: 0 4px;
  padding: 0 14px;
  border-bottom: none;
  border-radius: 999px;
  color: var(--c-ink-2);
}
.channel-bar-menu :deep(.el-menu-item:hover) {
  background: var(--c-surface);
  color: var(--c-ink-1);
}
.channel-bar-menu :deep(.el-menu-item.is-active) {
  background: var(--el-color-primary-light-9);
  color: var(--el-color-primary);
  font-weight: 600;
}

/* 左侧频道卡片：暖白底 + 柔和阴影 */
.channel-card {
  border-radius: 18px;
  background: var(--c-card);
  box-shadow: 0 2px 10px var(--c-shadow);
}

/* 竖向频道导航：去掉 el-menu 默认边框与背景，选中项用浅色胶囊 + 左侧短竖线 */
.channel-menu {
  border-right: none;
  --el-menu-bg-color: transparent;
  --el-menu-hover-bg-color: transparent;
  --el-menu-item-height: auto;
  --el-menu-active-color: var(--el-color-primary);
}
.channel-menu :deep(.el-menu-item) {
  @apply flex-y-center rounded-10px px-3 py-2 text-14px;
  height: auto;
  line-height: 1.5;
  margin-bottom: 2px;
  color: var(--c-ink-2);
  transition: background-color 0.15s ease, color 0.15s ease;
}
.channel-menu :deep(.el-menu-item:hover) {
  background-color: var(--c-surface);
  color: var(--c-ink-1);
}
.channel-menu :deep(.el-menu-item.is-active) {
  background: linear-gradient(90deg, var(--el-color-primary-light-9), transparent);
  font-weight: 600;
  color: var(--el-color-primary);
}
.channel-menu :deep(.el-menu-item.is-active::before) {
  content: '';
  width: 3px;
  height: 14px;
  margin-right: 8px;
  border-radius: 999px;
  background: var(--el-color-primary);
}
</style>