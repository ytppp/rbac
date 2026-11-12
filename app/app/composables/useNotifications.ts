/**
 * 站内通知的未读数：顶栏铃铛用它显示红点，通知页刷新后同步。
 */
export function useNotifications() {
  const unread = useState('notification-unread', () => 0)
  const { isLoggedIn, authHeaders } = useAuth()

  async function fetchUnread() {
    if (!isLoggedIn.value) {
      unread.value = 0
      return
    }

    try {
      const result = await $fetch<{ unread: number }>('/notifications', {
        baseURL: useApiBase(),
        headers: authHeaders(),
        query: { per_page: 1 },
      })
      unread.value = result.unread
    } catch {
      // 通知拉取失败不影响主流程
      unread.value = 0
    }
  }

  return { unread, fetchUnread }
}
