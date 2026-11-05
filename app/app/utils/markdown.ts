import { marked } from 'marked'

export interface TocItem {
  level: number
  text: string
  id: string
}

const stripHtml = (html: string): string =>
  html
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .trim()

/**
 * 把 Markdown 渲染成 HTML，并同步抽取目录。
 *
 * 标题 id 默认是 `md-heading-序号`；同一页面有多段正文时传入 idPrefix 做隔离，
 * 避免不同段的标题 id 重复。详情页按「段」结构绑定行程与图片，不再依赖标题顺序。
 */
export function renderMarkdown(
  markdown: string,
  idPrefix = '',
): { html: string; toc: TocItem[] } {
  const source = (markdown || '').trim()
  if (!source) {
    return { html: '', toc: [] }
  }

  const html = marked.parse(source, { gfm: true, breaks: true, async: false }) as string
  const toc: TocItem[] = []
  let index = 0

  const withIds = html.replace(/<h([1-6])>([\s\S]*?)<\/h\1>/g, (_match, level: string, inner: string) => {
    const id = `${idPrefix}md-heading-${index}`
    toc.push({ level: Number(level), text: stripHtml(inner), id })
    index += 1
    return `<h${level} id="${id}">${inner}</h${level}>`
  })

  return { html: withIds, toc }
}
