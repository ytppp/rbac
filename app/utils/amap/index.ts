import type {
  AMapOptions,
  AMapLoaderOptions,
  PartialAMapLoaderOptions,
  RoutePlanningOptions,
  MarkerConfig,
  SearchOptions,
} from './amap-extensions.d'
import {
  DefaultLoaderOptions,
  DefaultMapOptions,
  DefaultMarkerConfig,
  DefaultRoutePlanningOptions,
} from './config'

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
  private driving: any = null

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
  async routePlanning(options: RoutePlanningOptions): Promise<AMap.RouteResult> {
    if (!this.AMap) {
      await this.initMap()
    }
    if (!this.driving) {
      this.driving = new this.AMap.Driving({
        map: this.map,
        ...DefaultRoutePlanningOptions,
        ...options,
      })
    }
    if (!options.waypoints || !options.waypoints.length) {
      options.waypoints = []
    }
    return new Promise((resolve, reject) => {
      if (!options.origin || !options.destination || options.origin.equals(options.destination)) {
        return reject(new Error('必须设置起点与终点,且起点与终点不能相同'))
      }
      this.driving.search(
        options.origin,
        options.destination,
        { waypoints: options.waypoints },
        (status: string, result: AMap.RouteResult) => {
          if (status === 'complete') {
            resolve(result)
          } else {
            reject(new Error(`路线规划失败: ${status}`))
          }
        },
      )
    })
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

  clearDriving(): void {
    if (!this.map) return
    this.driving?.clear()
  }

  /**
   * 清除所有覆盖物
   */
  clearOverlays(): void {
    if (!this.map) return

    this.markers.clear()
    this.polylines.clear()
    this.polygons.clear()
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
