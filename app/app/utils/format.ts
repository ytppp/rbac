/**
 * 点赞数展示：中文超过 1 万折算成「1.2万」，英文按 1.2K 展示
 */
export function formatLikes(count: number, locale = 'zh') {
  if (locale.startsWith('zh')) {
    return count >= 10000 ? `${(count / 10000).toFixed(1)}万` : String(count)
  }

  return count >= 1000 ? `${(count / 1000).toFixed(1)}K` : String(count)
}
