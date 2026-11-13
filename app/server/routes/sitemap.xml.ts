// 站点地图：首页 + 全部已发布内容
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const siteBase = String(config.public.siteBase || '').replace(/\/+$/, '')
  const apiBase = String(config.public.apiBase || '')

  let ids: number[] = []
  try {
    const data = await $fetch<{ items: Array<{ id: number }> }>('/notes', {
      baseURL: apiBase,
      query: { per_page: 100 },
    })
    ids = data.items.map((item) => item.id)
  } catch {
    // api 暂不可用时也要返回一个合法的空 sitemap
    ids = []
  }

  const urls = [`${siteBase}/`, ...ids.map((id) => `${siteBase}/explore/${id}`)]
  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((url) => `  <url><loc>${url}</loc></url>`).join('\n')}
</urlset>`

  setHeader(event, 'content-type', 'application/xml; charset=utf-8')
  return body
})
