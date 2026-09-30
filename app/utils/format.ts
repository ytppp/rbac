/** 点赞数展示：超过 1 万折算成「1.2万」 */
export function formatLikes(count: number) {
  if (count >= 10000) return `${(count / 10000).toFixed(1)}万`

  return String(count)
}
