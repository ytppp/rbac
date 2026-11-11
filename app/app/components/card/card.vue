<template>
  <!-- 统一用 el-card 承载：header / 内容 / footer 三块，样式通过 class 透传 -->
  <el-card
    class="app-card"
    :class="{ 'app-card--no-border': !border, 'app-card--rounded': rounded }"
    :shadow="shadow"
  >
    <template v-if="header || $slots.header" #header>
      <div :class="headerClass">
        <template v-if="header">{{ header }}</template>
        <slot v-else name="header" />
      </div>
    </template>

    <div :class="bodyClass" :style="bodyStyle">
      <template v-if="content">{{ content }}</template>
      <slot v-else />
    </div>

    <template v-if="footer || $slots.footer" #footer>
      <div :class="footerClass">
        <template v-if="footer">{{ footer }}</template>
        <slot v-else name="footer" />
      </div>
    </template>
  </el-card>
</template>

<script setup lang="ts">
type shadowType = 'never' | 'always' | 'hover'

interface CardProps {
  header?: string // 卡片头部
  content?: string // 卡片内容
  footer?: string // 卡片底部内容
  border?: boolean // 是否显示边框
  rounded?: boolean // 是否显示圆角
  shadow?: shadowType // 阴影显示方式
  headerClass?: string // header 的 CSS 类名
  bodyStyle?: Record<string, string> // body 的 CSS 样式
  bodyClass?: string // body 的 CSS 类名
  footerClass?: string // footer 的 CSS 类名
}

withDefaults(defineProps<CardProps>(), {
  border: true,
  rounded: true,
  shadow: 'always',
})
</script>

<style scoped>
/* el-card 默认内边距 20px，这里归零，由调用方的 bodyClass 控制间距 */
.app-card {
  width: 100%;
  --el-card-padding: 0;
  --el-card-border-color: var(--c-line);
  --el-card-bg-color: var(--c-card);
}

.app-card--no-border {
  border: none;
}

.app-card--rounded {
  border-radius: 8px;
}
</style>
