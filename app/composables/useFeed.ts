import type { Ref } from 'vue'
import { ref, watch } from 'vue'

/** 顶栏搜索框和首页瀑布流共用的筛选状态 */
export function useFeed() {
  const keyword = useState('feed-keyword', () => '')
  const channel = useState('feed-channel', () => '推荐')

  return { keyword, channel }
}

/** 输入防抖：停顿 delay 毫秒后才把值同步出去，避免每敲一个字就打一次接口 */
export function useDebouncedRef<T>(source: Ref<T>, delay = 300) {
  const debounced = ref(source.value) as Ref<T>
  let timer: ReturnType<typeof setTimeout> | undefined

  watch(source, (value) => {
    clearTimeout(timer)
    timer = setTimeout(() => {
      debounced.value = value
    }, delay)
  })

  return debounced
}
