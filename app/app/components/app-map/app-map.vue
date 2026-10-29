<template>
  <div class="relative w-full h-full">
    <div id="map" class="w-full h-full"/>
    <div
      class="absolute top-[10px] left-2 flex-x-between mx-auto py-2 px-3 w-[30%] bg-black opacity-60 rounded-md shadow-xl text-white"
    >
      <div>
        <h3 class="text-sm font-bold p-0 m-0">{{ $t('trans0002') }}</h3>
        <ul class="list-none p-0 mt-2 mb-0 text-xs">
          <li>{{ $t('trans0003') }}</li>
          <li>{{ $t('trans0004') }}</li>
          <li>{{ $t('trans0005') }}</li>
          <li>{{ $t('trans0006') }}</li>
        </ul>
      </div>
      <div>
        <el-button type="primary" round>{{ $t('trans0007') }}</el-button>
      </div>
    </div>
    <transition name="el-fade-in-linear">
      <div
        v-if="isEditMarker"
        class="absolute top-[10px] right-2 py-2 px-3 bg-white rounded-md shadow-xl text-black"
        :class="{ 'w-[30%]': !isFold }"
      >
        <div class="text-right">
          <el-tooltip :content="$t('trans0015')" placement="bottom" effect="light">
            <icon
              v-show="isFold"
              class="text-2xl cursor-pointer"
              name="i-carbon:right-panel-open"
              @click="isFold = false"
            />
          </el-tooltip>
          <el-tooltip :content="$t('trans0016')" placement="bottom" effect="light">
            <icon
              v-show="!isFold"
              class="text-2xl cursor-pointer"
              name="i-carbon:right-panel-close"
              @click="isFold = true"
            />
          </el-tooltip>
          <el-tooltip :content="$t('trans0017')" placement="bottom" effect="light">
            <icon
              class="text-2xl cursor-pointer"
              name="i-carbon:close"
              @click="closeEditMarkerDialog"
            />
          </el-tooltip>
        </div>
        <el-collapse-transition>
          <el-tabs v-show="!isFold" v-model="activeTabName">
            <el-tab-pane :label="$t('trans0008')" :name="TabName.Config">
              <el-form :model="form" label-width="auto">
                <el-form-item :label="$t('trans0010')">
                  <el-input v-model="form.position" disabled />
                </el-form-item>
                <el-form-item :label="$t('trans0011')">
                  <el-input v-model="form.coordinate" disabled />
                </el-form-item>
                <el-form-item :label="$t('trans0012')">
                  <el-input v-model="form.desc" type="textarea" />
                </el-form-item>
                <el-form-item :label="$t('trans0013')">
                  <el-upload
                    drag
                    action="https://run.mocky.io/v3/9d059bf9-4660-45f2-925d-ce80ad6c4d15"
                    multiple
                  >
                    <icon class="text-2xl cursor-pointer" name="i-carbon:cloud-upload" />
                    <div class="el-upload__text">Drop file here or <em>click to upload</em></div>
                    <template #tip>
                      <div class="el-upload__tip">jpg/png files with a size less than 500kb</div>
                    </template>
                  </el-upload>
                </el-form-item>
                <el-form-item>
                  <el-button type="primary" @click="onSubmit">{{ $t('trans0007') }}</el-button>
                  <el-button @click="closeEditMarkerDialog">{{ $t('trans0014') }}</el-button>
                </el-form-item>
              </el-form>
            </el-tab-pane>
            <el-tab-pane :label="$t('trans0009')" :name="TabName.Preview">Preview</el-tab-pane>
          </el-tabs>
        </el-collapse-transition>
      </div>
    </transition>
  </div>
</template>

<script setup lang="tsx">
import AMapUtils from '~/utils/amap'
import type {
  MarkerConfig,
  MarkExtData,
  MarkerEvent,
  ReverseGeocodeResult,
  AddMarkerEvent,
  MapPoint,
  TripSegment,
} from '~/utils/amap/amap-extensions'
import type { PropType } from 'vue'

const props = defineProps({
  afterInit: {
    type: Function,
    default: () => {},
  },
  isGetCurPosWhenInit: {
    type: Boolean,
    default: false,
  },
  // 外部传入的位置点，第一个为起点、最后一个为终点、中间为途经点
  points: {
    type: Array as PropType<MapPoint[]>,
    default: () => [],
  },
  // 外部传入的行程（多段，按顺序），每段按交通方式绘制折线、中点图标与耗时
  trip: {
    type: Array as PropType<TripSegment[]>,
    default: () => [],
  },
})


interface FormData {
  id: string
  position: string
  coordinate: string
  desc: string
}

const markerStyleConfig = {
  start: { outerColor: 'bg-green-400', innerColor: 'bg-green-500', text: 'S' },
  end: { outerColor: 'bg-red-400', innerColor: 'bg-red-500', text: 'E' },
  via: { outerColor: 'bg-sky-400', innerColor: 'bg-sky-500', text: 'V' },
} as const
const TabName = {
  Config: 'config',
  Preview: 'preview',
} as const
type TabNameType = (typeof TabName)[keyof typeof TabName]
const config = useRuntimeConfig()
const { t } = useI18n()
const aMapUtils = ref<AMapUtils | null>(null)
const lineId = ref<string | null>(null)
const activeTabName = ref<TabNameType>(TabName.Config)
const isFold = ref<boolean>(false) // 配置弹窗是否折叠, 默认不折叠
const isEditMarker = ref<boolean>(false) // 是否正在编辑标记点
const form = ref<FormData>({
  id: '', // 当前正在编辑的标记点id
  position: '',
  coordinate: '',
  desc: '',
})

const resetForm = () => {
  form.value = {
    id: '',
    position: '',
    coordinate: '',
    desc: '',
  }
}
const onSubmit = () => {
  console.log('表单提交:', form.value)
  closeEditMarkerDialog()
}
const closeEditMarkerDialog = () => {
  const marker = aMapUtils.value?.getMarkerById(form.value.id)
  isEditMarker.value = false
  if (marker) {
    const newExtData = {
      ...marker.getExtData(),
      isEdit: false,
    }
    marker.setExtData(newExtData)
    const markerContent = createMarkerContent(newExtData)
    marker.setContent(markerContent)
  }
  resetForm()
}

const createMarkerContent = (markerExtData: MarkExtData): string => {
  const style = markerStyleConfig[markerExtData.type]
  return `
    <div class="flex size-6">
      <span class="absolute h-full w-full animate-ping rounded-full ${
        style.outerColor
      } opacity-75 ${markerExtData.isEdit ? 'inline-flex' : 'hidden'}"></span>
      <span class="relative inline-flex-center size-6 rounded-full ${
        style.innerColor
      } text-sm text-white select-none">
        ${style.text}
      </span>
    </div>
  `
}

// 处理标记点拖拽结束事件
const handleMarkerDragEnd = async (marker: MarkerEvent) => {
  try {
    const newCoordinate = marker.target.getPosition()
    const regeocode = (await aMapUtils.value?.reverseGeocode(newCoordinate)) as ReverseGeocodeResult

    form.value.coordinate = newCoordinate.toString()
    form.value.position = regeocode.formattedAddress || ''
    planRouteAndPolyline()
  } catch (error) {
    console.error('标记点拖拽结束处理失败:', error)
  }
}

// 处理标记点右键点击事件, 移除标记点
const handleMarkerRightClick = (marker: MarkerEvent) => {
  const extData = marker.target.getExtData()
  if (extData.type === 'start' || extData.isEdit) {
    return
  }

  const total = aMapUtils.value?.removeMarkerById(extData.id)
  if (total) {
    planRouteAndPolyline()
  } else {
    lineId.value = null
  }
}

// 处理标记点双击事件
const handleMarkerDblClick = (marker: MarkerEvent) => {
  if (isEditMarker.value) {
    return
  }

  const extData = marker.target.getExtData()
  extData.isEdit = isEditMarker.value = true

  form.value.id = extData.id || ''
  form.value.position = extData.name
  form.value.coordinate = marker.target.getPosition().toString()

  const markerContent = createMarkerContent(extData)
  marker.target.setContent(markerContent)
  marker.target.setExtData(extData)
}

const addMarker = async (e: AddMarkerEvent) => {
  if (isEditMarker.value) {
    closeEditMarkerDialog()
  }
  try {
    const regeocode = (await aMapUtils.value?.reverseGeocode(e.lnglat)) as ReverseGeocodeResult
    const amap = aMapUtils.value?.getAMap()
    if (!amap) {
      throw new Error('地图实例未初始化')
    }
    const markerOptions: MarkerConfig = {
      position: e.lnglat,
      title: t('trans0018'),
      offset: new amap.Pixel(-12, -12),
      cursor: 'pointer',
      extData: {
        name: regeocode.formattedAddress || '',
        type: 'start',
        isEdit: false,
      },
      onDragEnd: handleMarkerDragEnd,
      onRightClick: handleMarkerRightClick,
      onDblClick: handleMarkerDblClick,
    }

    const markers = aMapUtils.value?.getMarkers()
    if (markers && markers.length === 0) {
      lineId.value = `polyline_${Date.now()}_${Math.random()}`
      markerOptions.extData!.type = 'start'
    } else {
      // 如果已有多个标记点，将最后一个标记点类型改为via
      if (markers && markers.length > 1) {
        updateLastMarkerTypeToVia(markers)
      }
      // 将当前添加的标记点类型改为end
      markerOptions.extData!.type = 'end'
    }

    // 创建并添加标记点
    const markerContent = createMarkerContent(markerOptions.extData!)
    markerOptions.content = markerContent
    aMapUtils.value?.addMarker(markerOptions)

    // 规划路线和绘制折线
    planRouteAndPolyline()
  } catch (error) {
    console.error('添加标记点失败:', error)
  }
}

const updateLastMarkerTypeToVia = (markers: [string, AMap.Marker][]) => {
  const last = markers[markers.length - 1]
  if (last) {
    const extData: MarkExtData = last[1].getExtData()
    const newExtData: MarkExtData = {
      ...extData,
      type: 'via',
    }
    last[1].setExtData(newExtData)
    const markerContent = createMarkerContent(newExtData)
    last[1].setContent(markerContent)
  }
}

// 渲染外部传入的位置点：清空已有覆盖物后按 起点/途经点/终点 重建并规划路线
const renderPoints = (points: MapPoint[]) => {
  const utils = aMapUtils.value
  const amap = utils?.getAMap()
  if (!utils || !amap) {
    return
  }
  // 重置编辑态与已有覆盖物
  isEditMarker.value = false
  resetForm()
  utils.cleanMarkers()
  utils.clearPolyline()
  utils.clearDriving()
  lineId.value = null
  if (!points.length) {
    return
  }

  points.forEach((point, index) => {
    const type = index === 0 ? 'start' : index === points.length - 1 ? 'end' : 'via'
    const extData: MarkExtData = {
      name: point.name ?? '',
      type,
      isEdit: false,
    }
    utils.addMarker({
      position: new amap.LngLat(point.lng, point.lat),
      offset: new amap.Pixel(-12, -12),
      cursor: 'pointer',
      extData,
      content: createMarkerContent(extData),
      onDragEnd: handleMarkerDragEnd,
      onRightClick: handleMarkerRightClick,
      onDblClick: handleMarkerDblClick,
    })
  })
  planRouteAndPolyline()
  utils.setFitView()
}

// 渲染外部传入的行程：每段折线 + 折线中点交通图标 + 高德返回的耗时标注
const renderTrip = async (segments: TripSegment[]) => {
  const utils = aMapUtils.value
  if (!utils) {
    return
  }
  await utils.drawTrip(segments)
}

const planRouteAndPolyline = () => {
  try {
    const allMarkersPos = getMarkersPos()

    // 如果标记点少于2个，清除路线并返回
    if (allMarkersPos.length < 2) {
      aMapUtils.value?.clearDriving()
      aMapUtils.value?.clearPolyline()
      lineId.value = null
      return
    }

    // 绘制驾车路线
    const origin = allMarkersPos[0]
    const destination = allMarkersPos[allMarkersPos.length - 1]

    // 确保lineId存在
    if (!lineId.value) {
      lineId.value = `polyline_${Date.now()}_${Math.random()}`
    }

    // 绘制驾车折线
    aMapUtils.value?.addPolyline(allMarkersPos, {
      id: lineId.value!,
    })
    aMapUtils.value
      ?.routePlanning({
        origin: origin!,
        destination: destination!,
        waypoints: allMarkersPos.slice(1, allMarkersPos.length - 1),
      })
      .then(() => {
        // 路线规划成功后的处理
        console.log('路线规划成功')
      })
      .catch((error) => {
        console.error('路线规划失败:', error)
      })
  } catch (error) {
    console.error('规划路线和绘制折线失败:', error)
  }
}

const getMarkersPos = (): AMap.LngLat[] => {
  const markers = aMapUtils.value?.getMarkers()
  if (!markers || !markers.length) {
    return []
  }
  return markers.map((item) => item[1].getPosition()) as AMap.LngLat[]
}

const initMap = () => {
  const mapContainer = document.getElementById('map') as HTMLDivElement
  if (!mapContainer) {
    console.error('地图容器元素不存在')
    return
  }
  // 检查地图配置是否完整
  if (!config.public.AMapKey || !config.public.AMapSecurityJsCode) {
    console.error('地图配置不完整，请检查AMapKey和AMapSecurityJsCode')
    return
  }
  aMapUtils.value = new AMapUtils(mapContainer, {
    securityJsCode: config.public.AMapSecurityJsCode,
    amapKey: config.public.AMapKey,
  })
  aMapUtils.value
    .initMap()
    .then(() => {
      console.log('地图初始化成功')
      if (props.afterInit) {
        props.afterInit()
      }
      if (props.isGetCurPosWhenInit) {
        aMapUtils.value?.getCurrentPosition().then((position) => {
          console.log('当前位置:', position)
        })
      }
      // 初始化完成后渲染外部传入的位置点
      if (props.points.length) {
        renderPoints(props.points)
      }
      // 初始化完成后渲染外部传入的行程
      if (props.trip.length) {
        renderTrip(props.trip)
      }
      // aMapUtils.value?.on('click', addMarker)
    })
    .catch((error) => {
      console.error('地图初始化失败:', error)
    })
}

/**
 * 地图初始化
 */
onMounted(() => {
  initMap()
})

onUnmounted(() => {
  try {
    aMapUtils.value?.destroy()
    aMapUtils.value = null
    console.log('地图实例已销毁')
  } catch (error) {
    console.error('销毁地图实例失败:', error)
  }
})

// 外部点位变化时增量重绘
watch(() => props.points, renderPoints, { deep: true })
// 外部行程变化时重绘
watch(() => props.trip, renderTrip, { deep: true })

defineExpose({
  // 注意：setup 阶段 aMapUtils.value 还是 null，必须暴露 getter
  getAMapUtils: () => aMapUtils.value,
  addMarker,
  renderPoints,
  renderTrip,
})
</script>

<style></style>