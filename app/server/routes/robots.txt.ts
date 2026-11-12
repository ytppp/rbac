export default defineEventHandler((event) => {
  const config = useRuntimeConfig()
  const siteBase = String(config.public.siteBase || '').replace(/\/+$/, '')

  setHeader(event, 'content-type', 'text/plain; charset=utf-8')
  return `User-agent: *\nAllow: /\n\nSitemap: ${siteBase}/sitemap.xml\n`
})
