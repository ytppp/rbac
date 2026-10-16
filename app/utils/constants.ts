export const Theme = {
  auto: 'auto',
  light: 'light',
  dark: 'dark',
} as const

export type ThemeType = (typeof Theme)[keyof typeof Theme]
