// @ts-check
import withNuxt from './.nuxt/eslint.config.mjs'

export default withNuxt(
  // your custom flat configs go here, for example:
  {
    files: ['**/*.ts', '**/*.tsx'],
    rules: {
      'no-console': 'off', // allow console.log in TypeScript files
      'no-unused-vars': 'off', // allow unused variables in TypeScript files
    }
  },
  // {
  //   ...
  // }// Your custom configs here
)
