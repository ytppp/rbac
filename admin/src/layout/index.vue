<template>
  <el-container class="app-layout">
    <el-aside width="220px" class="app-aside">
      <div class="app-logo">{{ appTitle }}</div>
      <SidebarMenu />
    </el-aside>

    <el-container>
      <el-header height="56px" class="app-header">
        <Navbar />
      </el-header>
      <el-main class="app-main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import Navbar from './components/Navbar.vue'
import SidebarMenu from './components/SidebarMenu.vue'

const appTitle = import.meta.env.VITE_APP_TITLE || '权限管理平台'
</script>

<style scoped>
.app-layout {
  height: 100vh;
}

.app-aside {
  background-color: #001529;
  overflow-y: auto;
}

.app-logo {
  height: 56px;
  line-height: 56px;
  text-align: center;
  color: #fff;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 1px;
  background-color: #002140;
}

.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fff;
  border-bottom: 1px solid #e4e7ed;
  padding: 0 16px;
}

.app-main {
  background-color: #f0f2f5;
  padding: 0;
  overflow-y: auto;
}
</style>
