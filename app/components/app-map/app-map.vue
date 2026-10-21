<template>
  <div class="relative w-full h-full">
    <div id="map" class="w-full h-full"></div>
    <slot />
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
} from '~/utils/amap/amap-extensions'

const props = defineProps({
  afterInit: {
    type: Function,
    default: () => {},
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
      // aMapUtils.value?.getCurrentPosition().then((position) => {
      //   console.log('当前位置:', position)
      // })
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

defineExpose({
  initMap,
})
</script>

<style></style>