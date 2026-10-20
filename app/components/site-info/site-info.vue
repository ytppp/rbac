<template>
  <!-- 版权、备案等信息：宽屏放右栏，窄屏跟在内容列表末尾 -->
  <div class="text-12px text-ink-3">
    <div v-for="(row, i) in linkRows" :key="i" class="flex flex-wrap gap-x-4 gap-y-1 leading-[20px]">
      <el-link v-for="item in row" :key="item" class="site-link" underline="never">{{ item }}</el-link>
    </div>

    <div class="mt-3 leading-[22px]">
      <p class="m-0">投稿邮箱：hi@example.com</p>
      <p class="m-0">电话：010-8888 8888</p>
      <p class="m-0">ICP 备案号：沪 ICP 备 00000000 号-1</p>
      <p class="m-0">公安网安备 31000000000000 号</p>
    </div>

    <p class="mt-3 mb-0 leading-[22px]">© 2026 发现</p>
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
.site-link {
  font-size: 12px;
  color: var(--c-ink-3);
}
.site-link:hover {
  color: var(--el-color-primary);
}
</style>
