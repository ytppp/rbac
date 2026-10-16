<template>
  <div
    class="flex flex-col w-full h-full overflow-hidden cursor-pointer"
    :class="[
      {
        'border-1 border-solid border-line': border,
        'rounded-lg': rounded,
      },
      shadowClass,
    ]"
  >
    <!-- 卡片头部 -->
    <div :class="headerClass">
      <template v-if="header">{{ header }}</template>
      <slot name="header" v-else></slot>
    </div>
    <!-- 卡片内容 -->
    <div class="flex-1" :class="bodyClass" :style="bodyStyle">
      <template v-if="content">{{ content }}</template>
      <slot v-else></slot>
    </div>
    <!-- 卡片底部 -->
    <div :class="footerClass">
      <template v-if="footer">{{ footer }}</template>
      <slot name="footer" v-else></slot>
    </div>
  </div>
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

const props = withDefaults(defineProps<CardProps>(), {
  border: true,
  rounded: true,
  shadow: 'always',
})

const shadowClass = computed(() => {
  const str = 'transition-shadow duration-300'
  switch (props.shadow) {
    case 'never':
      return `shadow-none`
    case 'always':
      return `shadow-lg ${str}`
    case 'hover':
      return `hover:shadow-lg ${str}`
    default:
      return 'shadow-none'
  }
})
</script>
