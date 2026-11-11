<template>
  <div class="min-h-full">
    <NuxtLoadingIndicator />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </div>
</template>

<script setup lang="ts">
const { t, locale } = useI18n()

// 页面标题、描述与 html lang 跟随当前语言
useHead({
  htmlAttrs: { lang: () => (locale.value === 'zh' ? 'zh-CN' : locale.value) },
  title: () => t('meta.title'),
  meta: [{ name: 'description', content: () => t('meta.description') }],
})
</script>
