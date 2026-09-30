/**
 * 内容接口的基地址。
 * SSR 走容器内网直连 api 服务，浏览器走宿主机地址（后端 CORS 已放行 app 的来源）。
 * 两个值分别用 NUXT_API_SERVER_BASE / NUXT_PUBLIC_API_BASE 覆盖。
 */
export function useApiBase() {
  const config = useRuntimeConfig()

  return import.meta.server ? config.apiServerBase : config.public.apiBase
}
