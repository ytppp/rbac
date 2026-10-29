import '@amap/amap-jsapi-types'

type AMapPlugin =
  | 'AMap.Marker'
  | 'AMap.ControlBar'
  | 'AMap.ToolBar'
  | 'AMap.Scale'
  | 'AMap.HawkEye'
  | 'AMap.Driving'
  | 'AMap.Walking'
  | 'AMap.Geocoder'
  | 'AMap.Polyline'
  | 'AMap.Polygon'
  | 'AMap.Geolocation'
  | 'AMap.InfoWindow'
  | 'AMap.PlaceSearch'
  | 'AMap.DistrictSearch'

declare global {
  interface Window {
    _AMapSecurityConfig: {
      securityJsCode: string
    }
    AMap: typeof AMap
  }
  namespace AMap {
    // 扩展类型声明
    interface Map {
      // 如果有额外的自定义方法可以在这里声明
    }

    interface PlaceSearchResult {
      info: string // 状态信息，例如：OK
      poiList: {
        pois: AMap.POI[] // 搜索到的 POI 数组
      }
    }

    interface GeocodeResult {
      info: string // 状态信息，例如：OK
      geocodes: AMap.Geocode[] // 地理编码结果数组
    }

    interface ReGeocodeResult {
      info: string // 状态信息，例如：OK
      regeocodes: AMap.ReGeocode[] // 逆地理编码结果数组
      address: string
    }

    interface GeolocationResult {
      success: boolean // 是否成功定位
      info: string // 状态信息，例如：OK
      position: AMap.LngLat | null // 定位坐标
      accuracy: number // 定位精度，单位：米
    }

    interface DistrictSearchResult {
      info: string // 状态信息，例如：OK
      districts: AMap.District[] // 区域信息数组
    }

    interface RouteResult {
      info: string // 状态信息，例如：OK
      routes: AMap.DrivingRoute[] // 驾车路线数组
      origin: AMap.LngLat // 规划起点坐标
      destination: AMap.LngLat // 规划终点坐标
    }

    // 工具类用到的自定义接口
    interface CustomMarkerOptions extends AMap.MarkerOptions {
      id?: string
      data?: Record<string, any>
    }

    interface PolylineOptionsExt extends AMap.PolylineOptions {
      id?: string
      data?: Record<string, any>
    }

    interface PolygonOptionsExt extends AMap.PolygonOptions {
      id?: string
      data?: Record<string, any>
    }
  }
}

export interface AMapLoaderOptions {
  securityJsCode: string // 安全密钥
  amapKey: string // 高德地图 API 密钥
  version: string // 指定要加载的 JSAPI 的版本
  plugins?: AMapPlugin[] // 需要加载的插件
  // 是否加载 AMapUI，缺省不加载
  AMapUI?: {
    version?: string // AMapUI 缺省 1.1
    plugins?: string[] // 需要加载的 AMapUI ui插件
  }
  // 是否加载 Loca， 缺省不加载
  Loca?: {
    version?: string // Loca 版本，缺省 1.3.2
  }
}

export type PartialAMapLoaderOptions = Partial<AMapLoaderOptions>

export type PickAMapLoaderOptions = Omit<AMapLoaderOptions, 'securityJsCode' | 'amapKey'>

export interface AMapOptions extends AMap.MapOptions {
  showDefaultUI?: boolean // 是否显示默认 UI 组件
}

export interface RoutePlanningOptions {
  // 交通方式
  type: TransportType
  origin: AMap.LngLat
  destination: AMap.LngLat
  waypoints?: AMap.LngLat[] // 途经点，最多 20 个
  policy?: AMap.DrivingPolicy // 驾车策略
  ferry?: boolean // 是否包含轮渡
  province?: string // 车牌省份的汉字缩写，用于判断是否限行，与number属性组合使用，可选。例如：京
  number?: string // 除省份之外车牌的字母和数字，用于判断限行相关，与province属性组合使用，可选。例如:NH1N11
  hideMarkers?: boolean // 是否隐藏默认起始标记点
}

export type PickRoutePlanningOptions = Omit<RoutePlanningOptions, 'origin' | 'destination'>

// 行程段的交通方式
export type TransportType = 'plane' | 'driving' | 'walking'

// 位置点信息
export interface MapPoint {
  lng: number
  lat: number
  name?: string
  desc?: string
}

export interface TripSegment {
  type: TransportType
  // 起点
  origin: MapPoint
  // 终点
  destination: MapPoint
  // 直接指定折线路径（如航班航迹），不传则按 type 走高德路线规划
  path?: [number, number][]
  // 已知道的耗时（秒），优先于接口返回的耗时
  duration?: number
  // 折线颜色，缺省按交通方式取默认色
  color?: string
  // 该段是否已完成：已完成实线，未完成虚线
  completed?: boolean
}

export interface TripSegmentResult {
  type: TransportType
  path: AMap.LngLat[]
  // 耗时（秒）。高德未提供航班耗时时为空
  duration?: number
  // 距离（米）。航班段为空
  distance?: number
}

export type MarkerType = 'start' | 'end' | 'via'
export interface MarkExtData {
  type: MarkerType
  name: string
  isEdit: boolean
}

export interface MarkerEvent {
  target: any
  [key: string]: any
}
export interface ReverseGeocodeResult {
  formattedAddress: string
  [key: string]: any
}
export interface AddMarkerEvent {
  lnglat: any
  [key: string]: any
}
export interface MarkerConfig extends AMap.CustomMarkerOptions {
  id?: string
  onDragStart?: (marker: MarkerEvent) => void
  onDrag?: (marker: MarkerEvent) => void
  onDragEnd?: (marker: MarkerEvent) => void
  onClick?: (marker: MarkerEvent) => void
  onMouseOver?: (marker: MarkerEvent) => void
  onMouseOut?: (marker: MarkerEvent) => void
  onComplete?: (marker: MarkerEvent) => void
  onRightClick?: (marker: MarkerEvent) => void
  onDblClick?: (marker: MarkerEvent) => void
  extData?: MarkExtData
}

export interface SearchOptions {
  city?: string
  citylimit?: boolean
  pageSize?: number
  pageIndex?: number
  extensions?: 'base' | 'all'
}
