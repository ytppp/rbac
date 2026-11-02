<template>
  <div class="w-full h-full">
    <div class="w-full" style="height: 600px">
      <app-map :trip="trip" />
    </div>
    <div>
      <div>图片轮播</div>
      <div>内容</div>
    </div>
    <!-- 版权信息放在地图下方，宽度与首页「瀑布流 + 版权」一致 -->
    <site-info class="mt-6" />
  </div>
</template>

<script setup lang="ts">
import type { TripSegment } from '~/utils/amap/amap-extensions'

// 版权信息改到页面底部展示，隐藏布局右侧的固定栏
definePageMeta({ hideSiteInfo: true })

const trip: TripSegment[] = [
  {
    type: 'plane',
    origin: { lng: 116.4109, lat: 39.9163, name: '北京首都国际机场' },
    destination: { lng: 121.8081, lat: 31.1455, name: '上海浦东国际机场' },
    duration: 8100,
    completed: true,
  },
  {
    type: 'driving',
    origin: { lng: 121.8081, lat: 31.1455, name: '上海浦东国际机场' },
    destination: { lng: 121.4905, lat: 31.2402, name: '上海外滩' },
    completed: true,
  },
  {
    type: 'walking',
    origin: { lng: 121.4905, lat: 31.2402, name: '上海外滩' },
    destination: { lng: 121.5005, lat: 31.2397, name: '南京路步行街' },
    completed: false,
  },
]
</script>
