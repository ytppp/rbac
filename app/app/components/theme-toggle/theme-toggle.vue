<template>
  <el-dropdown>
    <div class="flex-y-center h-full">
      <el-button link>
        <icon :name="themeIcon" />
        <!-- <span class="ml-1">{{ themeLabel }}</span> -->
      </el-button>
    </div>
    <template #dropdown>
      <el-dropdown-menu>
        <el-dropdown-item
          v-for="item in themeList"
          :key="item.value"
          :value="item.value"
          @click="toggleTheme(item.value)"
        >
          <icon class="text-sm" :name="item.icon" />
          <span class="ml-1 text-sm">{{ item.label }}</span>
        </el-dropdown-item>
      </el-dropdown-menu>
    </template>
  </el-dropdown>
</template>

<script setup lang="ts">
import { useStorage } from '@vueuse/core'
interface ThemeItem {
  label: string
  value: ThemeType
  icon: string
}

const isDark = useDark()
const interval = 1000 * 60 // 1分钟
const currentTheme = ref<ThemeType>(Theme.light)
const isAutoToggleTheme = useStorage('is-auto-toggale-theme', false)
const { t } = useI18n()
const themeConfig = {
  [Theme.auto]: {
    icon: 'i-carbon:window-black-saturation',
  },
  [Theme.light]: {
    icon: 'i-carbon:sun',
  },
  [Theme.dark]: {
    icon: 'i-carbon:moon',
  },
}
// 名称跟随当前语言
const themeList = computed<ThemeItem[]>(() => [
  {
    label: t('theme.auto'),
    value: Theme.auto,
    icon: themeConfig[Theme.auto].icon,
  },
  {
    label: t('theme.light'),
    value: Theme.light,
    icon: themeConfig[Theme.light].icon,
  },
  {
    label: t('theme.dark'),
    value: Theme.dark,
    icon: themeConfig[Theme.dark].icon,
  },
])

// const themeLabel = computed(() => themeConfig[currentTheme.value].label)
const themeIcon = computed(() => {
  return themeConfig[currentTheme.value].icon
})

const checkTimeAndToggleTheme = () => {
  if (!isAutoToggleTheme.value) return
  const d = new Date().getHours()
  const isNight = d > 18 || d < 8
  isDark.value = isNight
}

const toggleTheme = (theme: ThemeType) => {
  currentTheme.value = theme
  switch (theme) {
    case Theme.auto:
      isAutoToggleTheme.value = true
      checkTimeAndToggleTheme()
      useIntervalFn(() => {
        checkTimeAndToggleTheme()
      }, interval)
      break
    case Theme.light:
      isAutoToggleTheme.value = false
      isDark.value = false
      break
    case Theme.dark:
      isAutoToggleTheme.value = false
      isDark.value = true
      break
  }
}
const initTheme = () => {
  if (isAutoToggleTheme.value) {
    toggleTheme(Theme.auto)
  } else {
    const theme = isDark.value ? Theme.dark : Theme.light
    toggleTheme(theme)
  }
}

onMounted(() => {
  initTheme()
})
</script>
