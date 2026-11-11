<template>
  <div class="auth-page relative flex min-h-screen items-center justify-center px-24px py-40px">
    <!-- 左上角品牌 logo，右上角主题 / 语言切换 -->
    <NuxtLink :to="localePath('/')" class="absolute left-24px top-16px flex items-center gap-10px text-ink-1 no-underline">
      <span class="travel-mark h-30px w-30px rounded-9px text-17px">
        <icon name="i-carbon:compass" />
      </span>
      <span class="flex flex-col leading-[1.15] max-md:hidden">
        <span class="text-17px font-600 tracking-[1px]">{{ $t('brand.name') }}</span>
        <span class="text-[9px] tracking-[0.24em] text-ink-3">{{ $t('brand.sub') }}</span>
      </span>
    </NuxtLink>

    <div class="absolute right-24px top-16px flex-y-center">
      <theme-toggle />
      <el-divider direction="vertical" />
      <locale-toggle />
    </div>

    <!-- 登录 / 注册共用的表单卡片 -->
    <el-card class="auth-card w-full max-w-360px" shadow="always">
      <slot />
    </el-card>
  </div>
</template>

<script setup lang="ts">
// 品牌 logo 回首页时保留当前语言前缀
const localePath = useLocalePath()
</script>

<style scoped>
/* 登录 / 注册页背景：沿用全站的暖沙底，再叠一层海面与日落光晕 */
.auth-page {
  background-color: var(--c-page);
  background-image:
    radial-gradient(720px 420px at 78% 18%, rgba(126, 200, 212, 0.26), transparent 62%),
    radial-gradient(620px 360px at 18% 82%, rgba(242, 121, 90, 0.14), transparent 60%);
}

.auth-card {
  border: 1px solid var(--c-line);
  border-radius: 24px;
  background: var(--c-card);
  box-shadow: 0 20px 60px var(--c-shadow);
}

.auth-card :deep(.el-card__body) {
  padding: 32px 28px;
}

/* 表单：间距与输入框样式在两个页面保持一致 */
.auth-card :deep(.el-form-item) {
  margin-bottom: 16px;
}
.auth-card :deep(.el-form-item__label) {
  @apply mb-6px h-auto text-13px text-ink-2;
  padding: 0;
  line-height: 1.4;
}
.auth-card :deep(.el-input__wrapper) {
  @apply rounded-10px px-14px;
  background-color: var(--c-surface);
  box-shadow: 0 0 0 1px var(--c-line) inset;
}
.auth-card :deep(.el-input__wrapper:hover) {
  box-shadow: 0 0 0 1px var(--c-line) inset;
}
.auth-card :deep(.el-input__wrapper.is-focus) {
  background-color: var(--c-card);
  box-shadow: 0 0 0 1px var(--el-color-primary) inset;
}
.auth-card :deep(.el-input__inner) {
  @apply text-14px text-ink-1;
}
.auth-card :deep(.submit-btn) {
  @apply h-42px w-full;
  font-size: 15px;
}

/* 底部「去注册 / 去登录」引导 */
.auth-card :deep(.auth-switch) {
  margin: 18px 0 0;
  color: var(--c-ink-3);
  font-size: 12px;
  text-align: center;
}
.auth-card :deep(.auth-switch a) {
  color: var(--el-color-primary);
  font-weight: 500;
  text-decoration: none;
}
</style>
