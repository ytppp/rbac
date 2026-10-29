import type {
  PickAMapLoaderOptions,
  AMapOptions,
  PickRoutePlanningOptions,
  MarkerConfig,
} from './amap-extensions'

export const DefaultLoaderOptions: PickAMapLoaderOptions = {
  version: '2.0',
  plugins: [
    'AMap.Marker',
    'AMap.ControlBar',
    'AMap.ToolBar',
    'AMap.Scale',
    'AMap.HawkEye',
    'AMap.Driving',
    'AMap.Walking',
    'AMap.Geocoder',
    'AMap.Polyline',
    'AMap.Polygon',
    'AMap.Geolocation',
    'AMap.InfoWindow',
    'AMap.PlaceSearch',
    'AMap.DistrictSearch',
  ],
}

export const DefaultMapOptions: AMapOptions = {
  showDefaultUI: false,
  viewMode: '2D',
  zoom: 18,
  // center: [116.397428, 39.90923], // 地图初始化中心位置，不传则默认定位到用户位置
}

export const DefaultRoutePlanningOptions: PickRoutePlanningOptions = {
  ferry: true,
  hideMarkers: true,
}

export const DefaultMarkerConfig: MarkerConfig = {
  draggable: true,
}
