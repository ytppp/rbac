<template>
  <div :class="name"></div>
</template>

<script setup lang="ts">
interface IconProps {
  name: string // 图标名称,采用carbon图标库的图标名称 https://icones.js.org/collection/carbon
  title?: string // 图标标题
}

defineProps<IconProps>()
</script>
