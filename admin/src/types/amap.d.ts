import '@amap/amap-jsapi-types'

declare global {
  interface Window {
    // JSAPI 2.0 的安全密钥，必须在加载地图前挂到 window 上
    _AMapSecurityConfig?: {
      securityJsCode: string
    }
  }
}
