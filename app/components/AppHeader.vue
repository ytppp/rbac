<template>
  <header class="app-header">
    <div class="header-inner">
      <NuxtLink to="/" class="brand">
        <span class="brand-mark">发</span>
        <span class="brand-name">发现</span>
      </NuxtLink>

      <div class="search">
        <svg class="search-icon" viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="7" />
          <path d="M20 20l-3.6-3.6" />
        </svg>
        <input
          v-model="keyword"
          class="search-input"
          type="search"
          placeholder="搜索你感兴趣的内容"
        />
      </div>

      <div class="header-actions">
        <button class="btn-publish" type="button">发布</button>
        <span class="avatar">我</span>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { useFeed } from '~/composables/useFeed'

const { keyword } = useFeed()
</script>
