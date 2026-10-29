<template>
  <div class="w-full h-full">
    <div class="w-full" style="height: 600px">
      <app-map :trip="trip" />
    </div>
    <div>
      <div>图片轮播</div>
      <div>内容</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { TripSegment } from '~/utils/amap/amap-extensions'

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
