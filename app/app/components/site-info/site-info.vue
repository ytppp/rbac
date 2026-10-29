<template>
  <!-- 版权、备案等信息：宽屏放右栏，窄屏跟在内容列表末尾 -->
  <div class="text-12px text-ink-3">
    <!-- 链接组：圆角浅底卡片，避免裸文本显得单薄 -->
    <card :border="true" rounded shadow="hover" class="site-panel" body-class="!p-14px">
      <div v-for="(row, i) in linkRows" :key="i" class="flex flex-wrap gap-x-4 gap-y-1 leading-[20px]">
        <el-link v-for="item in row" :key="item" class="site-link" underline="never">{{ item }}</el-link>
      </div>
    </card>

    <!-- 联系与备案信息 -->
    <card :border="true" rounded shadow="hover" class="mt-3 site-panel" body-class="!p-14px">
      <div class="leading-[22px]">
        <p class="m-0">投稿邮箱：hi@example.com</p>
        <p class="m-0 mt-6px">电话：010-8888 8888</p>
        <p class="m-0 mt-6px">ICP 备案号：沪 ICP 备 00000000 号-1</p>
        <p class="m-0 mt-6px">公安网安备 31000000000000 号</p>
      </div>
    </card>

    <p class="mt-4 mb-0 text-center leading-[22px] text-ink-3">© 2026 发现</p>
  </div>
</template>

<script setup lang="ts">
/** 备案号、联系方式等都是占位内容，上线前替换成真实信息 */
const linkRows = [
  ['用户协议', '营业执照', '隐私政策', '关于我们'],
  ['使用指南', '友情链接', '更多文章']
]
</script>

<style scoped>
/* 右栏信息面板：与左侧导航、内容卡片统一的圆角卡片观感 */
.site-panel {
  background-color: var(--c-card);
}
.site-link {
  font-size: 12px;
  color: var(--c-ink-2);
}
.site-link:hover {
  color: var(--el-color-primary);
}
</style>