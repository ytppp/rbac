<template>
  <el-menu
    :default-active="activeMenu"
    router
    unique-opened
    background-color="#001529"
    text-color="#c0c4cc"
    active-text-color="#ffffff"
    class="sidebar-menu"
  >
    <SidebarItem v-for="menu in permissionStore.menus" :key="menu.id" :menu="menu" />
  </el-menu>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { usePermissionStore } from '@/stores/permission'
import SidebarItem from './SidebarItem.vue'

const route = useRoute()
const permissionStore = usePermissionStore()

const activeMenu = computed(() => route.path)
</script>

<style scoped>
.sidebar-menu {
  border-right: none;
}
</style>
