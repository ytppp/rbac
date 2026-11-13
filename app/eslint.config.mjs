// @ts-check
import withNuxt from './.nuxt/eslint.config.mjs'

export default withNuxt(
  {
    files: ['**/*.ts', '**/*.tsx', '**/*.vue'],
    rules: {
      'no-console': 'off', // allow console.log in TypeScript files
      'no-unused-vars': 'off', // allow unused variables in TypeScript files
      // 高德地图 SDK 与接口错误对象的类型不完整，业务里允许显式 any
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-empty-object-type': 'off',
    }
  },
)
