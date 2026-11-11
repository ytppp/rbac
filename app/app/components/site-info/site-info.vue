<template>
  <!-- 版权、备案等信息：宽屏放右栏，窄屏跟在内容列表末尾 -->
  <div class="text-12px text-ink-3">
    <!-- 链接组：圆角浅底卡片，避免裸文本显得单薄 -->
    <card :border="true" rounded shadow="never" class="site-panel" body-class="!p-14px">
      <p class="travel-eyebrow m-0 mb-2">TRAVEL NOTES</p>
      <div v-for="(row, i) in linkRows" :key="i" class="flex flex-wrap gap-x-4 gap-y-1 leading-[20px]">
        <el-link v-for="item in row" :key="item" class="site-link" underline="never">{{ item }}</el-link>
      </div>
    </card>

    <!-- 联系与备案信息 -->
    <card :border="true" rounded shadow="never" class="mt-3 site-panel" body-class="!p-14px">
      <div class="leading-[22px]">
        <p class="m-0">{{ $t('site.email') }}</p>
        <p class="m-0 mt-6px">{{ $t('site.phone') }}</p>
        <p class="m-0 mt-6px">{{ $t('site.icp') }}</p>
        <p class="m-0 mt-6px">{{ $t('site.police') }}</p>
      </div>
    </card>

    <p class="mt-4 mb-0 text-center leading-[22px] text-ink-3">{{ $t('site.copyright') }}</p>
  </div>
</template>

<script setup lang="ts">
const { t } = useI18n()

/** 备案号、联系方式等都是占位内容，上线前替换成真实信息 */
const linkRows = computed(() => [
  [t('site.linkAgreement'), t('site.linkLicense'), t('site.linkPrivacy'), t('site.linkAbout')],
  [t('site.linkGuide'), t('site.linkFriends'), t('site.linkMore')],
])
</script>

<style scoped>
/* 右栏信息面板：与左侧导航、内容卡片统一的圆角卡片观感 */
.site-panel {
  background-color: var(--c-card);
  border-radius: 18px;
  box-shadow: 0 2px 10px var(--c-shadow);
}
.site-link {
  font-size: 12px;
  color: var(--c-ink-2);
}
.site-link:hover {
  color: var(--el-color-primary);
}
</style>