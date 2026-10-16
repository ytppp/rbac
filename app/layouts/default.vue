<template>
  <div class="isolate">
    <app-header />
    <main class="flex-x-center pt-[90px]">
      <div class="content-width flex gap-5" style="height: calc(100vh - 90px)">
        <div class="flex-1">
          <slot />
        </div>
        <div class="w-xs" style="height: 80%">
          <card footer-class="p-2" :border="false">
            <el-menu class="side-menu">
              <el-menu-item index="explore">
                <icon name="i-carbon:explore" />
                <span>探索</span>
              </el-menu-item>
              <el-menu-item index="publish">
                <icon name="i-carbon:cloud-upload" />
                <span>发布</span>
              </el-menu-item>
              <el-menu-item index="me">
                <icon name="i-carbon:user-avatar" />
                <span>我</span>
              </el-menu-item>
            </el-menu>
            <div class="flex-x-center py-5 border-0 border-t border-solid border-gray-200">
              <el-button type="primary" round>登录</el-button>
            </div>
            <template #footer>
              <div class="flex-y-center gap-2 px-10 py-4">
                <icon name="i-carbon:list" />
                <span>更多</span>
              </div>
            </template>
          </card>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts"></script>

<style scoped>
/* 侧栏导航：去掉默认右边框与悬停底色，尺寸贴近旧设计 */
.side-menu {
  border-right: none;
  --el-menu-bg-color: transparent;
  --el-menu-hover-bg-color: transparent;
  --el-menu-item-height: auto;
}
.side-menu :deep(.el-menu-item) {
  @apply flex-y-center gap-2 px-10 py-4 text-14px;
  height: auto;
  line-height: 1.5;
}
</style>
