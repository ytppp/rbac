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
      title: '发现 - 记录你的生活灵感',
      htmlAttrs: { lang: 'zh-CN' },
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'description', content: '一个内容发现社区，用瀑布流浏览穿搭、美食、旅行与生活灵感。' }
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
    defaultLocale: 'en',
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
