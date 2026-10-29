<template>
  <el-dropdown>
    <div class="flex-y-center h-full">
      <el-button link>
        <icon name="i-carbon:ibm-watson-language-translator" />
      </el-button>
    </div>
    <template #dropdown>
      <el-dropdown-menu>
        <el-dropdown-item
          v-for="locale in locales"
          :key="locale.code"
          @click="setLocale(locale.code)"
          >{{ locale.name }}</el-dropdown-item
        >
      </el-dropdown-menu>
    </template>
  </el-dropdown>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'

const { locales, setLocale } = useI18n()
</script>
