export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  devtools: { enabled: false },
  // 全局样式：项目语义色变量 + 瀑布流插件自带样式
  css: ['~/assets/style/main.css', 'vue-waterfall-plugin-next/dist/style.css'],
  typescript: {
    typeCheck: true,
  },
  runtimeConfig: {
    // SSR 时直连 api 容器，走容器内网，不涉及跨域
    apiServerBase: 'http://localhost:3000/api/v1',
    public: {
      // 浏览器直连 api，跨域由后端的 CORS_ORIGINS 放行
      apiBase: 'http://localhost:3000/api/v1',
      // 管理后台地址：app 顶栏的「发布」入口用它拼 SSO 地址
      adminBase: process.env.ADMIN_BASE || 'http://localhost:5173',
      // 站点对外地址：sitemap / robots / OG 链接用
      siteBase: process.env.SITE_BASE || 'http://localhost:3001',
      AMapKey: process.env.AMAP_KEY,
      AMapSecurityJsCode: process.env.AMAP_SECURITY_JS_CODE,
    }
  },
  modules: [
    '@nuxt/eslint',
    '@nuxtjs/i18n',
    '@unocss/nuxt',
    '@vueuse/nuxt',
    '@pinia/nuxt',
    '@element-plus/nuxt',
  ],
  // routeRules: {
  //   '/': {
  //     redirect: '/explore',
  //   },
  // },
  app: {
    head: {
      title: '发现 · 旅行手记',
      htmlAttrs: { lang: 'zh-CN' },
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'description', content: '一个记录旅行的内容社区：用地图串起行程，用照片收藏沿途风景。' }
      ]
    }
  },
  devServer: {
    host: '0.0.0.0',
    port: 3000
  },
  vite: {
    server: {
      // 容器内 bind mount 的文件变更事件不稳定，开启轮询保证 HMR 可用
      watch: { usePolling: true }
    }
  },
  i18n: {
    defaultLocale: 'zh',
    langDir: '../i18n/locales/',
    locales: [
      { code: 'en', name: 'English', file: 'en-US.json' },
      { code: 'zh', name: 'Chinese', file: 'zh-CN.json' },
    ],
  },
  components: [
    {
      path: '~/components',
      pathPrefix: false,
    },
  ],
})
