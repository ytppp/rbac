<template>
  <div class="location-picker">
    <el-input
      :model-value="display"
      readonly
      placeholder="搜索地点，或在地图上点选"
      class="location-picker__input"
      @click="openDialog"
    >
      <template #append>
        <el-button :icon="Location" @click.stop="openDialog">选择地点</el-button>
      </template>
    </el-input>

    <div class="location-picker__meta">
      <span v-if="hasPoint" class="coord">{{ formatCoord(modelValue) }}</span>
      <span v-else class="hint">不用再手填经纬度</span>
      <el-button v-if="hasPoint" link type="danger" @click="clear">清除</el-button>
    </div>

    <el-dialog
      v-model="visible"
      title="选择地点"
      width="760px"
      top="6vh"
      append-to-body
      destroy-on-close
      @opened="initMap"
      @closed="destroyMap"
    >
      <div class="picker-body">
        <div class="picker-search">
          <el-input
            v-model="keyword"
            placeholder="搜索地点，如：上海外滩"
            clearable
            @keyup.enter="handleSearch"
          />
          <el-button type="primary" :loading="searching" @click="handleSearch">搜索</el-button>
        </div>

        <ul v-if="results.length" class="picker-results">
          <li v-for="poi in results" :key="poi.id ?? `${poi.name}-${poi.location.lng}`" @click="selectPoi(poi)">
            <span class="poi-name">{{ poi.name }}</span>
            <span v-if="poi.address" class="poi-address">{{ poi.address }}</span>
          </li>
        </ul>

        <div v-if="mapError" class="picker-error">{{ mapError }}</div>
        <div v-else ref="mapEl" v-loading="mapLoading" class="picker-map" />

        <div class="picker-selected">
          <el-input
            v-model="draft.name"
            placeholder="地点名称（选点后自动填充，可修改）"
            :disabled="!hasDraft"
          />
          <span class="coord">{{ hasDraft ? formatCoord(draft) : '尚未选点' }}</span>
        </div>

        <p class="picker-tip">
          搜索地点或在图上点击，标记可拖动微调；确认后自动回填名称与经纬度。
        </p>
      </div>

      <template #footer>
        <el-button @click="visible = false">取消</el-button>
        <el-button type="primary" @click="confirm">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import AMapLoader from '@amap/amap-jsapi-loader'
import { ElMessage } from 'element-plus'
import { Location } from '@element-plus/icons-vue'
import type { NoteSectionPoint } from '@/types'

// 高德类型包只覆盖核心 API，这里按实际用到的字段补上地点搜索与逆地理编码
interface PoiItem {
  id?: string
  name: string
  address?: string
  location: { lng: number; lat: number }
}

interface PlaceSearchInstance {
  search(
    keyword: string,
    callback: (status: string, result: { poiList?: { pois?: PoiItem[] } }) => void,
  ): void
}

interface GeocoderInstance {
  getAddress(
    position: [number, number],
    callback: (status: string, result: { regeocodes?: { formattedAddress?: string }[] }) => void,
  ): void
}

type AMapApi = typeof AMap & {
  PlaceSearch: new (options?: {
    pageSize?: number
    extensions?: 'base' | 'all'
  }) => PlaceSearchInstance
  Geocoder: new (options?: { radius?: number }) => GeocoderInstance
}

const props = defineProps<{ modelValue: NoteSectionPoint }>()
const emit = defineEmits<{ 'update:modelValue': [value: NoteSectionPoint] }>()

const amapKey = import.meta.env.VITE_AMAP_KEY
const securityJsCode = import.meta.env.VITE_AMAP_SECURITY_JS_CODE
// 没有已选点时，地图默认落在天安门附近
const DEFAULT_CENTER: [number, number] = [116.397428, 39.90923]

const visible = ref(false)
const mapLoading = ref(false)
const mapError = ref('')
const searching = ref(false)
const keyword = ref('')
const results = ref<PoiItem[]>([])
const draft = ref<NoteSectionPoint>({})
const mapEl = ref<HTMLDivElement>()

let api: AMapApi | null = null
let map: AMap.Map | null = null
let marker: AMap.Marker | null = null
let placeSearch: PlaceSearchInstance | null = null
let geocoder: GeocoderInstance | null = null

const hasPoint = computed(
  () => typeof props.modelValue.lng === 'number' && typeof props.modelValue.lat === 'number',
)
const hasDraft = computed(
  () => typeof draft.value.lng === 'number' && typeof draft.value.lat === 'number',
)
const display = computed(() => {
  if (!hasPoint.value) return ''
  const name = props.modelValue.name?.trim()
  return name ? `${name}（${formatCoord(props.modelValue)}）` : formatCoord(props.modelValue)
})

function formatCoord(point: NoteSectionPoint) {
  return `${point.lng?.toFixed(6)}, ${point.lat?.toFixed(6)}`
}

function openDialog() {
  draft.value = { ...props.modelValue }
  keyword.value = props.modelValue.name ?? ''
  results.value = []
  mapError.value = ''
  visible.value = true
}

async function initMap() {
  if (!amapKey || !securityJsCode) {
    mapError.value = '未配置高德地图 Key，请在 admin 环境变量中设置 VITE_AMAP_KEY 与 VITE_AMAP_SECURITY_JS_CODE'
    return
  }

  mapLoading.value = true
  try {
    window._AMapSecurityConfig = { securityJsCode }
    api = (await AMapLoader.load({
      key: amapKey,
      version: '2.0',
      plugins: ['AMap.PlaceSearch', 'AMap.Geocoder'],
    })) as AMapApi

    const center: [number, number] = hasDraft.value
      ? [draft.value.lng!, draft.value.lat!]
      : DEFAULT_CENTER

    map = new api.Map(mapEl.value as HTMLDivElement, {
      zoom: hasDraft.value ? 15 : 11,
      center,
      viewMode: '2D',
    })

    map.on('click', (event: { lnglat: AMap.LngLat }) => {
      results.value = []
      setPoint(event.lnglat.lng, event.lnglat.lat)
      fillNameByPosition(event.lnglat.lng, event.lnglat.lat)
    })

    placeSearch = new api.PlaceSearch({ pageSize: 10, extensions: 'base' })
    geocoder = new api.Geocoder({ radius: 1000 })

    if (hasDraft.value) {
      drawMarker(draft.value.lng!, draft.value.lat!)
    }
  } catch {
    mapError.value = '高德地图加载失败，请检查 Key、安全密钥与网络'
  } finally {
    mapLoading.value = false
  }
}

function drawMarker(lng: number, lat: number) {
  if (!api || !map) return

  if (!marker) {
    marker = new api.Marker({ position: [lng, lat], draggable: true, anchor: 'bottom-center' })
    marker.on('dragend', () => {
      const position = marker?.getPosition()
      if (!position) return
      setPoint(position.lng, position.lat)
      fillNameByPosition(position.lng, position.lat)
    })
    map.add(marker)
    return
  }

  marker.setPosition([lng, lat])
}

function setPoint(lng: number, lat: number, name?: string) {
  draft.value = { lng, lat, name }
  drawMarker(lng, lat)
}

/** 逆地理编码：把点击/拖动后的坐标换成人能看懂的地名 */
function fillNameByPosition(lng: number, lat: number) {
  if (!geocoder) return

  geocoder.getAddress([lng, lat], (status, result) => {
    if (status !== 'complete') return
    // 用户可能已经手动改了名称，或又点了别的位置，这两种情况都不覆盖
    if (draft.value.lng !== lng || draft.value.lat !== lat) return
    if (draft.value.name?.trim()) return
    const address = result.regeocodes?.[0]?.formattedAddress
    if (address) {
      draft.value = { ...draft.value, name: address }
    }
  })
}

function handleSearch() {
  const query = keyword.value.trim()
  if (!query) {
    ElMessage.warning('请输入要搜索的地点')
    return
  }
  if (!placeSearch) {
    ElMessage.warning(mapError.value || '地图尚未加载完成')
    return
  }

  searching.value = true
  placeSearch.search(query, (status, result) => {
    searching.value = false
    if (status !== 'complete') {
      results.value = []
      ElMessage.warning('没有找到相关地点，换个关键词试试')
      return
    }
    results.value = result.poiList?.pois ?? []
  })
}

function selectPoi(poi: PoiItem) {
  setPoint(poi.location.lng, poi.location.lat, poi.name)
  map?.setZoomAndCenter(16, [poi.location.lng, poi.location.lat])
  results.value = []
  keyword.value = poi.name
}

function confirm() {
  if (!hasDraft.value) {
    ElMessage.warning('请先搜索或在地图上点选地点')
    return
  }

  emit('update:modelValue', {
    lng: draft.value.lng,
    lat: draft.value.lat,
    name: draft.value.name?.trim() || undefined,
  })
  visible.value = false
}

function clear() {
  emit('update:modelValue', { name: '', lng: undefined, lat: undefined })
}

function destroyMap() {
  marker = null
  map?.destroy()
  map = null
  placeSearch = null
  geocoder = null
}
</script>

<style scoped>
.location-picker {
  width: 100%;
}

.location-picker__input :deep(.el-input__inner) {
  cursor: pointer;
}

.location-picker__meta {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 6px;
  min-height: 20px;
  font-size: 12px;
}

.coord {
  color: var(--el-text-color-secondary);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.hint {
  color: var(--el-text-color-placeholder);
}

.picker-body {
  position: relative;
}

.picker-search {
  display: flex;
  gap: 8px;
}

.picker-results {
  position: absolute;
  top: 42px;
  left: 0;
  right: 90px;
  z-index: 10;
  margin: 0;
  padding: 4px 0;
  max-height: 220px;
  overflow-y: auto;
  list-style: none;
  background: var(--el-bg-color-overlay);
  border: 1px solid var(--el-border-color-light);
  border-radius: 6px;
  box-shadow: var(--el-box-shadow-light);
}

.picker-results li {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 8px 12px;
  cursor: pointer;
}

.picker-results li:hover {
  background: var(--el-fill-color-light);
}

.poi-name {
  color: var(--el-text-color-primary);
  font-size: 14px;
}

.poi-address {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.picker-map {
  height: 360px;
  margin-top: 12px;
  border-radius: 8px;
  overflow: hidden;
  background: var(--el-fill-color-light);
}

.picker-error {
  margin-top: 12px;
  padding: 12px;
  border-radius: 8px;
  background: var(--el-color-warning-light-9);
  color: var(--el-color-warning);
  font-size: 13px;
}

.picker-selected {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 12px;
}

.picker-selected .el-input {
  flex: 1;
}

.picker-tip {
  margin: 10px 0 0;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}
</style>
