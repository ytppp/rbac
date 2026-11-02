import type {
  AMapOptions,
  AMapLoaderOptions,
  PartialAMapLoaderOptions,
  RoutePlanningOptions,
  RoutePlanningResult,
  MarkerConfig,
  MarkerType,
  MapPoint,
  SearchOptions,
  TripSegment,
  TripSegmentResult,
  TransportType,
} from './amap-extensions'
import {
  DefaultLoaderOptions,
  DefaultMapOptions,
  DefaultMarkerConfig,
  DefaultRoutePlanningOptions,
} from './config'

// 各交通方式的默认折线颜色与图标（图标类名见 uno.config.ts 的 safelist）
const TRIP_STYLE: Record<TransportType, { color: string; icon: string }> = {
  plane: { color: '#2563eb', icon: 'i-carbon:plane' },
  driving: { color: '#16a34a', icon: 'i-carbon:car' },
  walking: { color: '#ea580c', icon: 'i-carbon:pedestrian' },
}

// 秒 -> 可读耗时
const formatDuration = (seconds?: number): string => {
  if (!seconds || seconds <= 0) {
    return ''
  }
  const minutes = Math.round(seconds / 60)
  if (minutes < 60) {
    return `${minutes}分钟`
  }
  const hours = Math.floor(minutes / 60)
  const rest = minutes % 60
  return rest ? `${hours}小时${rest}分钟` : `${hours}小时`
}

/**
 * 高德地图自定义 Hook
 * @param container 地图容器 DOM 元素
 * @param loaderOptions 地图加载器配置
 * @param mapOptions 地图初始化配置
 */
export default class AMapUtils {
  private container: string | HTMLDivElement
  private loaderOptions: AMapLoaderOptions
  private AMap: any = null
  private map: AMap.Map | null = null
  // 地图上的标记点
  private markers: Map<string, AMap.Marker> = new Map()
  // 地图上的折线
  private polylines: Map<string, AMap.Polyline> = new Map()
  // 地图上的多边形
  private polygons: Map<string, AMap.Polygon> = new Map()
  private eventListeners: Map<string, any> = new Map()
  // 行程段产生的覆盖物（折线、交通图标、耗时气泡），用于整体清理
  private tripOverlays: any[] = []
  // 行程绘制序号：用于作废在途的旧绘制，避免并发叠加
  private tripSeq = 0

  /**
   * 构造函数
   * @param container 地图容器 DOM 元素
   * @param loaderOptions 地图加载器配置
   */
  constructor(container: string | HTMLDivElement, loaderOptions: PartialAMapLoaderOptions) {
    this.container = container
    this.loaderOptions = { ...DefaultLoaderOptions, ...loaderOptions } as AMapLoaderOptions
  }

  loadAPI(): Promise<typeof AMap> {
    return new Promise((resolve, reject) => {
      if (!this.loaderOptions.securityJsCode) {
        return reject(new Error('请配置 AMAP_SECURITY_JS_CODE 环境变量'))
      }
      window._AMapSecurityConfig = {
        securityJsCode: this.loaderOptions.securityJsCode,
      }
      if (!this.loaderOptions.amapKey) {
        return reject(new Error('请配置 AMAP_KEY 环境变量'))
      }
      import('@amap/amap-jsapi-loader')
        .then((AMapLoader) => {
          const AMap = AMapLoader.load({
            key: this.loaderOptions.amapKey,
            version: this.loaderOptions.version,
            plugins: this.loaderOptions.plugins,
          })
          resolve(AMap)
        })
        .catch(() => {
          return reject(new Error('加载高德地图 API 失败'))
        })
    })
  }

  /**
   * 初始化地图
   * @returns Promise<void>
   */
  async initMap(options?: AMapOptions) {
    this.AMap = await this.loadAPI()
    const mapOptions = {
      ...DefaultMapOptions,
      ...options,
    }
    this.map = new this.AMap.Map(this.container, mapOptions)
    if (mapOptions.showDefaultUI !== false) {
      this.map?.addControl(
        new this.AMap.ControlBar({
          visible: false,
          position: {
            top: '10px',
            right: '10px',
          },
        }),
      )
      this.map?.addControl(
        new this.AMap.ToolBar({
          visible: false,
          position: {
            top: '110px',
            right: '40px',
          },
        }),
      )
      this.map?.addControl(
        new this.AMap.Scale({
          visible: true,
        }),
      )
      this.map?.addControl(
        new this.AMap.HawkEye({
          visible: true,
        }),
      )
    }
  }

  /**
   * 绘制地图上的标记点
   * @param position 标记点位置信息
   */
  addMarker(config: MarkerConfig): AMap.Marker | undefined {
    if (!this.AMap) {
      console.error('AMap 未加载，请先初始化地图')
      return undefined
    }
    const markerId = config.id || `marker_${Date.now()}_${Math.random()}`
    const options = {
      ...DefaultMarkerConfig,
      ...config,
      extData: {
        ...config.extData,
        id: markerId,
      },
    }
    const marker = new this.AMap.Marker(options)
    this.map?.add(marker)
    this.markers.set(markerId, marker)
    // 添加事件监听
    if (options.draggable) {
      marker.on('dragstart', (e: any) => {
        options.onDragStart?.(e)
      })
      marker.on('dragging', (e: any) => {
        marker.setCursor('move')
        options.onDrag?.(e)
      })
      marker.on('dragend', (e: any) => {
        marker.setCursor('default')
        options.onDragEnd?.(e)
      })
    }

    // 点击事件
    marker.on('click', (e: any) => {
      options.onClick?.(e)
    })

    // 鼠标事件
    marker.on('mouseover', (e: any) => {
      options.onMouseOver?.(e)
    })
    marker.on('mouseout', (e: any) => {
      options.onMouseOut?.(e)
    })
    // 右键点击事件
    marker.on('rightclick', (e: any) => {
      options.onRightClick?.(e)
    })
    // 双击事件
    marker.on('dblclick', (e: any) => {
      options.onDblClick?.(e)
    })

    options.onComplete?.(marker)
    return marker
  }

  /**
   * 创建信息窗口
   */
  createInfoWindow(
    content: string | HTMLElement,
    position: [number, number],
  ): AMap.InfoWindow | undefined {
    if (!this.AMap) {
      console.error('AMap 未加载，请先初始化地图')
      return undefined
    }

    const infoWindow = new this.AMap.InfoWindow({
      content,
      position,
      offset: new this.AMap.Pixel(0, -30),
    })

    return infoWindow
  }

  /**
   * 绘制地图上的折线
   * @param path 折线路径数组 [lng, lat]
   * @param config 折线选项
   */
  addPolyline(path: AMap.LngLat[], config?: AMap.PolylineOptionsExt): AMap.Polyline | undefined {
    if (!this.AMap) {
      console.error('AMap 未加载，请先初始化地图')
      return undefined
    }
    let polyline: AMap.Polyline | undefined
    if (config?.id) {
      polyline = this.getOverlayById(config?.id) as AMap.Polyline
    }
    if (polyline) {
      polyline?.setPath(path as AMap.LngLatLike[])
    } else {
      const polylineId = config?.id || `polyline_${Date.now()}_${Math.random()}`
      polyline = new this.AMap.Polyline({
        path,
        strokeColor: '#3366FF',
        strokeWeight: 5,
        strokeStyle: 'solid',
        ...config,
        extData: {
          ...config?.extData,
          id: polylineId,
        },
      }) as AMap.Polyline
      this.map?.add(polyline)
      this.polylines.set(polylineId, polyline)
    }
    return polyline
  }

  /**
   * 添加多边形
   * @param path 多边形路径数组 [lng, lat]
   * @param config 多边形选项
   */
  addPolygon(path: AMap.LngLat[], config?: AMap.PolygonOptionsExt): AMap.Polygon | undefined {
    if (!this.AMap) {
      console.error('AMap 未加载，请先初始化地图')
      return undefined
    }
    let polygon: AMap.Polygon | undefined
    if (config?.id) {
      polygon = this.getOverlayById(config?.id) as AMap.Polygon
    }
    if (polygon) {
      polygon?.setPath(path as AMap.LngLatLike[])
    } else {
      const polygonId = config?.id || `polygon_${Date.now()}_${Math.random()}`
      polygon = new this.AMap.Polygon({
        path,
        fillColor: '#1791fc',
        fillOpacity: 0.3,
        strokeColor: '#1791fc',
        strokeWeight: 2,
        ...config,
        extData: {
          ...config?.extData,
          id: polygonId,
        },
      }) as AMap.Polygon
      this.map?.add(polygon)
      this.polygons.set(polygonId, polygon)
    }
    return polygon
  }

  /**
   * 地点搜索
   */
  async searchPlaces(
    keyword: string,
    options: SearchOptions = {},
  ): Promise<AMap.PlaceSearchResult['poiList']['pois']> {
    if (!this.AMap) {
      await this.initMap()
    }

    return new Promise((resolve) => {
      const placeSearch = new this.AMap.PlaceSearch({
        city: options.city || '全国',
        citylimit: options.citylimit || false,
        pageSize: options.pageSize || 10,
        pageIndex: options.pageIndex || 1,
        extensions: options.extensions || 'base',
      })

      placeSearch.search(keyword, (status: string, result: AMap.PlaceSearchResult) => {
        if (status === 'complete' && result.info === 'OK') {
          resolve(result.poiList.pois)
        } else {
          resolve([])
        }
      })
    })
  }

  /**
   * 地理编码（地址转坐标）
   */
  async geocode(address: string, city?: string): Promise<AMap.GeocodeResult> {
    if (!this.AMap) {
      await this.initMap()
    }
    return new Promise((resolve, reject) => {
      const geocoder = new this.AMap.Geocoder({
        city: city || '全国',
      })

      geocoder.getLocation(address, (status: string, result: AMap.GeocodeResult) => {
        if (status === 'complete' && result.info === 'OK') {
          resolve(result)
        } else {
          reject(new Error(`地理编码失败: ${status}`))
        }
      })
    })
  }

  /**
   * 逆地理编码（坐标转地址）
   * @param lnglat 经纬度数组 [lng, lat]
   */
  async reverseGeocode(lnglat: AMap.LngLat): Promise<any> {
    if (!this.AMap) {
      await this.initMap()
    }
    return new Promise((resolve, reject) => {
      const geocoder = new this.AMap.Geocoder()

      geocoder.getAddress(lnglat, (status: string, result: any) => {
        if (status === 'complete' && result.regeocode) {
          resolve(result.regeocode)
        } else {
          reject(new Error(`逆地理编码失败: ${status}`))
        }
      })
    })
  }

  /**
   * 获取当前位置
   */
  async getCurrentPosition(): Promise<AMap.GeolocationResult> {
    if (!this.AMap) {
      await this.initMap()
    }
    return new Promise((resolve, reject) => {
      const geolocation = new this.AMap.Geolocation({
        enableHighAccuracy: true, // 是否使用高精度定位，默认：true
        timeout: 10000, // 设置定位超时时间，默认：无穷大
        maximumAge: 0,
        convert: true,
        showButton: false,
        offset: [10, 20], // 定位按钮的停靠位置的偏移量
        zoomToAccuracy: true, // 定位成功后调整地图视野范围使定位位置及精度范围视野内可见，默认：false
        position: 'RB', // 定位按钮的排放位置,  RB表示右下
      })

      geolocation.getCurrentPosition((status: string, result: AMap.GeolocationResult) => {
        if (status === 'complete') {
          resolve(result)
        } else {
          reject(new Error(`获取位置失败: ${status}`))
        }
      })
    })
  }

  /**
   * 路线规划
   * @param options 路线规划选项
   * @returns Promise<AMap.RouteResult>
   */
  async routePlanning(options: RoutePlanningOptions): Promise<RoutePlanningResult> {
    if (!this.AMap) {
      await this.initMap()
    }
    const {
      type: mode,
      origin,
      destination,
      waypoints = [],
      drawOnMap = true,
      ...rest
    } = options
    const Service = mode === 'driving' ? this.AMap.Driving : this.AMap.Walking
    if (!Service) {
      throw new Error(`高德地图 ${mode} 服务不可用，请检查 plugins 配置`)
    }
    const service = new Service({
      // 不传 map 时服务只返回规划数据，不会在地图上再画一条
      ...(drawOnMap ? { map: this.map } : {}),
      ...DefaultRoutePlanningOptions,
      ...rest,
    })
    return new Promise((resolve, reject) => {
      if (!origin || !destination || origin.equals(destination)) {
        return reject(new Error('必须设置起点与终点,且起点与终点不能相同'))
      }
      const onComplete = (status: string, result: AMap.RouteResult) => {
        if (status !== 'complete') {
          return reject(new Error(`${mode} 路线规划失败: ${status}`))
        }
        const route = result?.routes?.[0]
        if (!route) {
          return reject(new Error(`${mode} 路线规划无结果`))
        }
        const path: AMap.LngLat[] = []
        route.steps?.forEach((step: any) => {
          step.path?.forEach((point: any) => path.push(point))
        })
        resolve({ ...result, path, duration: route.time, distance: route.distance })
      }
      // 步行接口只接受 (origin, destination, callback)，多传参数会丢回调
      if (mode === 'driving') {
        service.search(origin, destination, { waypoints }, onComplete)
      } else {
        service.search(origin, destination, onComplete)
      }
    })
  }

  /**
   * 规划单个行程段
   */
  async planTripSegment(segment: TripSegment): Promise<TripSegmentResult> {
    if (!this.AMap) {
      await this.initMap()
    }
    const origin = new this.AMap.LngLat(segment.origin.lng, segment.origin.lat)
    const destination = new this.AMap.LngLat(segment.destination.lng, segment.destination.lat)

    // 外部直接给了路径，或该方式无接口（航班），走直线
    if (segment.path?.length) {
      return {
        type: segment.type,
        path: segment.path.map(([lng, lat]) => new this.AMap.LngLat(lng, lat)),
        duration: segment.duration,
      }
    }
    if (segment.type === 'plane') {
      return {
        type: 'plane',
        path: [origin, destination],
        duration: segment.duration,
      }
    }

    const planned = await this.routePlanning({
      type: segment.type,
      origin,
      destination,
      // 行程自己按完成状态画折线（实线/虚线），不让服务再画一条
      drawOnMap: false,
    })
    return { type: segment.type, ...planned, duration: segment.duration ?? planned.duration }
  }

  /**
   * 交通工具图标：小圆标，压在两点直线上
   */
  private createTransportIcon(type: TransportType): string {
    const style = TRIP_STYLE[type]
    return `
      <div style="
        display:flex;align-items:center;justify-content:center;
        width:20px;height:20px;border-radius:9999px;
        background:${style.color};color:#fff;
        box-shadow:0 1px 4px rgba(0,0,0,.35);
      "><span class="${style.icon}" style="font-size:12px;line-height:1;"></span></div>
    `
  }

  /**
   * 耗时小标签：贴在交通工具图标右侧，不压线
   */
  private createTimeLabel(type: TransportType, label: string): string {
    const style = TRIP_STYLE[type]
    return `
      <div style="
        padding:1px 7px;border-radius:9999px;
        background:#ffffff;color:#111827;
        border:1px solid ${style.color};
        font-size:12px;line-height:16px;white-space:nowrap;
        box-shadow:0 1px 4px rgba(0,0,0,.18);
      ">${label}</div>
    `
  }

  /**
   * 行程点位序列：首段起点、末段终点，中间衔接点为途经点（连续相同坐标只保留一个）
   */
  private getTripPoints(segments: TripSegment[]): { point: MapPoint; type: MarkerType }[] {
    const raw: MapPoint[] = [segments[0]!.origin, ...segments.map((item) => item.destination)]
    const deduped = raw.filter(
      (point, index) => index === 0 || !this.isSamePoint(point, raw[index - 1]!),
    )
    return deduped.map((point, index) => {
      const type: MarkerType =
        index === 0 ? 'start' : index === deduped.length - 1 ? 'end' : 'via'
      return { point, type }
    })
  }

  private isSamePoint(a: MapPoint, b: MapPoint): boolean {
    return Math.abs(a.lng - b.lng) < 1e-6 && Math.abs(a.lat - b.lat) < 1e-6
  }

  /**
   * 绘制完整行程：每段画两条线（两点直线 + 行程规划线），
   * 交通工具图标与耗时挂在两点直线上，已完成实线、未完成虚线
   * @param segments 行程段列表，按顺序排列
   * @param pointContent 行程点位（start/end/via）的图标 HTML，由调用方决定样式
   */
  async drawTrip(
    segments: TripSegment[],
    pointContent?: (type: MarkerType) => string,
  ): Promise<TripSegmentResult[]> {
    this.clearTrip()
    if (!this.AMap || !this.map || !segments.length) {
      return []
    }
    const seq = this.tripSeq
    const results: TripSegmentResult[] = []
    const fitPoints: AMap.LngLat[] = []

    for (const segment of segments) {
      const start = new this.AMap.LngLat(segment.origin.lng, segment.origin.lat)
      const end = new this.AMap.LngLat(segment.destination.lng, segment.destination.lat)
      const linePath = [start, end]

      // 行程规划线（沿道路/步道），航班无规划接口，只有直线
      let planned: TripSegmentResult | undefined
      try {
        planned = await this.planTripSegment(segment)
      } catch (error) {
        console.error(`行程段（${segment.type}）规划失败，仅画直线:`, error)
      }
      // 等待期间若有新的绘制或清理，本次结果作废
      if (seq !== this.tripSeq) {
        return []
      }
      const routePath = planned?.path ?? []
      const hasRoute = routePath.length > 2

      const style = TRIP_STYLE[segment.type]
      const color = segment.color || style.color
      const strokeStyle = segment.completed ? 'solid' : 'dashed'
      // 未完成段降低不透明度，弱化存在感
      const strokeOpacity = segment.completed ? 1 : 0.55

      // 点击某段时把视野放大到这一段，便于看清短途段
      const focusSegment = () => this.fitPoints([...linePath, ...routePath])

      // 线 1：行程规划线（主视觉）
      if (hasRoute) {
        const routePolyline = new this.AMap.Polyline({
          path: routePath,
          strokeColor: color,
          strokeWeight: 4,
          strokeStyle,
          strokeOpacity,
          lineJoin: 'round',
          cursor: 'pointer',
          clickable: true,
          zIndex: 100,
        })
        routePolyline.on('click', focusSegment)
        this.map.add(routePolyline)
        this.tripOverlays.push(routePolyline)
      }

      // 线 2：两点直线（方向示意，细且淡）
      const linePolyline = new this.AMap.Polyline({
        path: linePath,
        strokeColor: color,
        strokeWeight: 1.5,
        strokeStyle,
        strokeOpacity: hasRoute ? strokeOpacity * 0.4 : strokeOpacity,
        lineJoin: 'round',
        cursor: 'pointer',
        clickable: true,
        zIndex: 105,
      })
      linePolyline.on('click', focusSegment)
      this.map.add(linePolyline)
      this.tripOverlays.push(linePolyline)

      // 交通工具图标放在两点连线中点
      const midLng = (segment.origin.lng + segment.destination.lng) / 2
      const midLat = (segment.origin.lat + segment.destination.lat) / 2
      const midPoint = new this.AMap.LngLat(midLng, midLat)
      const iconMarker = new this.AMap.Marker({
        position: midPoint,
        anchor: 'center',
        content: this.createTransportIcon(segment.type),
        cursor: 'default',
        zIndex: 160,
      })
      this.map.add(iconMarker)
      this.tripOverlays.push(iconMarker)

      // 耗时小标签贴在图标右侧
      const label = formatDuration(segment.duration ?? planned?.duration)
      if (label) {
        const labelMarker = new this.AMap.Marker({
          position: midPoint,
          offset: new this.AMap.Pixel(12, -9),
          cursor: 'default',
          content: this.createTimeLabel(segment.type, label),
          zIndex: 160,
        })
        this.map.add(labelMarker)
        this.tripOverlays.push(labelMarker)
      }

      fitPoints.push(...linePath, ...routePath)
      results.push({
        type: segment.type,
        path: linePath,
        duration: segment.duration ?? planned?.duration,
        distance: planned?.distance,
      })
    }

    // 行程点位标记
    if (pointContent) {
      this.getTripPoints(segments).forEach(({ point, type }) => {
        const marker = new this.AMap.Marker({
          position: new this.AMap.LngLat(point.lng, point.lat),
          offset: new this.AMap.Pixel(-12, -12),
          cursor: 'default',
          content: pointContent(type),
          zIndex: 150,
        })
        this.map!.add(marker)
        this.tripOverlays.push(marker)
      })
    }

    // 用所有路径点（含规划线）自己算包围盒再适配视野，setFitView 有时会把末段裁到屏幕外
    this.fitPoints(fitPoints)
    return results
  }

  /**
   * 按给定坐标点集合适配地图视野
   */
  private fitPoints(points: AMap.LngLat[]): void {
    if (!this.map || points.length < 2) {
      return
    }
    let minLng = Infinity
    let minLat = Infinity
    let maxLng = -Infinity
    let maxLat = -Infinity
    points.forEach((point) => {
      minLng = Math.min(minLng, point.getLng())
      maxLng = Math.max(maxLng, point.getLng())
      minLat = Math.min(minLat, point.getLat())
      maxLat = Math.max(maxLat, point.getLat())
    })
    if (!Number.isFinite(minLng) || !Number.isFinite(minLat)) {
      return
    }
    // 留 8% 边距，避免终点标记贴边被裁
    const padLng = (maxLng - minLng) * 0.08 || 0.005
    const padLat = (maxLat - minLat) * 0.08 || 0.005
    // Bounds 必须显式传西南角与东北角，无参构造得到的是无效盒
    const bounds = new this.AMap.Bounds(
      [minLng - padLng, minLat - padLat],
      [maxLng + padLng, maxLat + padLat],
    )
    this.map.setBounds(bounds)
  }

  /**
   * 清除行程相关的所有覆盖物（不影响其它标记与折线）
   */
  clearTrip(): void {
    // 序号自增，让在途的绘制在下一个 await 后自行作废
    this.tripSeq++
    if (!this.tripOverlays.length) {
      return
    }
    this.map?.remove(this.tripOverlays)
    this.tripOverlays = []
  }

  /**
   * 行政区划查询
   * @param keyword 搜索关键词
   * @param level 查询级别，默认district
   * @returns Promise<AMap.DistrictSearchResult>
   */
  async searchDistrict(
    keyword: string,
    level: 'country' | 'province' | 'city' | 'district' | 'biz_area' = 'district',
  ): Promise<AMap.DistrictSearchResult> {
    if (!this.AMap) {
      await this.initMap()
    }

    return new Promise((resolve, reject) => {
      const district = new this.AMap.DistrictSearch({
        level,
        extensions: 'all',
        subdistrict: 1,
      })

      district.search(keyword, (status: string, result: AMap.DistrictSearchResult) => {
        if (status === 'complete' && result.info === 'OK') {
          resolve(result)
        } else {
          reject(new Error(`行政区划查询失败: ${status}`))
        }
      })
    })
  }

  /**
   * 添加地图事件监听
   */
  on(event: AMap.EventType | AMap.EventType[], handler: (event: any) => void): void {
    if (!this.map) return

    const listener = this.map.on(event, handler)
    this.eventListeners.set(`${event}_${Date.now()}`, listener)
  }

  /**
   * 移除地图事件监听
   */
  off(event?: AMap.EventType | AMap.EventType[]): void {
    if (!this.map) return

    if (event) {
      // 移除特定事件
      this.eventListeners.forEach((listener, key) => {
        if (key.startsWith(event as string)) {
          // 移除事件监听
          const eventName = key.split('_')[0] as AMap.EventType
          this.map?.off(eventName, listener)
          this.eventListeners.delete(key)
        }
      })
    } else {
      // 移除所有事件
      this.eventListeners.forEach((listener, key) => {
        const eventName = key.split('_')[0] as AMap.EventType
        this.map?.off(eventName, listener)
      })
      this.eventListeners.clear()
    }
  }

  /**
   * 清除所有标记
   */
  cleanMarkers(): void {
    if (!this.map) return
    const markersArr = Array.from(this.markers.values())
    this.map.remove(markersArr)
    this.markers.clear()
  }

  /**
   * 清除所有折线
   */
  clearPolyline(): void {
    if (!this.map) return
    const polylinesArr = Array.from(this.polylines.values())
    this.map.remove(polylinesArr)
    this.polylines.clear()
  }

  /**
   * 清除所有多边形
   */
  clearPolygons(): void {
    if (!this.map) return
    const polygonsArr = Array.from(this.polygons.values())
    this.map.remove(polygonsArr)
    this.polygons.clear()
  }

  /**
   * 清除所有覆盖物
   */
  clearOverlays(): void {
    if (!this.map) return

    this.markers.clear()
    this.polylines.clear()
    this.polygons.clear()
    this.tripOverlays = []
    this.map.clearMap()
  }

  /**
   * 根据ID移除标记，如果清除所有标记，返回false，否则返回当前标记数量
   */
  removeMarkerById(id: string): boolean | number {
    const marker = this.markers.get(id)
    if (marker && this.map) {
      this.map.remove(marker)
      this.markers.delete(id)
      return this.markers.size === 0 ? false : this.getMarkers().length
    }
    return false
  }

  getMarkerById(id: string): AMap.Marker | undefined {
    return this.markers.get(id)
  }

  getMarkers(): [string, AMap.Marker][] {
    return Array.from(this.markers.entries())
  }

  getOverlayById(id: string): AMap.Polyline | AMap.Polygon | undefined {
    return this.polylines.get(id)
  }

  getOverlays(): [string, AMap.Polyline | AMap.Polygon][] {
    return Array.from(this.polylines) as [string, AMap.Polyline | AMap.Polygon][]
  }

  /**
   * 设置地图中心点和缩放级别
   */
  setView(center: [number, number], zoom?: number): void {
    if (!this.map) return

    this.map.setCenter(center)
    if (zoom !== undefined) {
      this.map.setZoom(zoom)
    }
  }

  /**
   * 获取地图当前视图范围
   */
  getBounds(): AMap.Bounds | null {
    if (!this.map) return null
    return this.map.getBounds()
  }

  /**
   * 将经纬度转换为地图容器坐标
   * @param points 经纬度数组 [lng, lat]
   * @returns 地图容器坐标数组 [x, y]
   */
  lngLatToContainer(points: number[]) {
    return this.map?.lngLatToContainer(points)
  }

  /**
   * 设置地图自适应视图
   */
  setFitView() {
    this.map?.setFitView()
  }

  /**
   * 获取地图实例
   * @returns 地图实例
   */
  getMap() {
    return this.map
  }

  /**
   * 获取高德地图实例, 用于调用高德地图 API
   * @returns 高德地图实例
   */
  getAMap() {
    return this.AMap
  }

  /**
   * 销毁地图实例
   */
  destroy(): void {
    if (this.map) {
      this.off() // 移除所有事件监听
      this.clearOverlays()
      this.map.destroy()
      this.map = null
    }
  }
}
