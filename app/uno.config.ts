import { defineConfig, presetUno } from 'unocss'

// 内容社区的样式配置。
// 原来散在 assets/css/main.css 里的颜色变量与基础样式，现在都由这里统一提供。
export default defineConfig({
  presets: [presetUno()],
  theme: {
    // 瀑布流按窗口宽度收窄列数，这里定义三个断点供 `max-md/lg/xl:` 变体使用
    breakpoints: {
      md: '760px',
      lg: '1100px',
      xl: '1500px',
    },
    colors: {
      brand: '#ff2e4d',
      page: '#f5f5f5',
      card: '#ffffff',
      line: '#ededed',
      ink: {
        1: '#1f1f1f',
        2: '#6b6b6b',
        3: '#9b9b9b',
      },
    },
  },
  // 基础样式：等价于原来 main.css 里的 `:root` / `*` / `html,body` / `body`
  preflights: [
    {
      getCSS: () => `
        *, *::before, *::after { box-sizing: border-box; }
        html, body { height: 100%; }
        body {
          margin: 0;
          background: #f5f5f5;
          color: #1f1f1f;
          font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Hiragino Sans GB',
            'Microsoft YaHei', 'Helvetica Neue', Arial, sans-serif;
          -webkit-font-smoothing: antialiased;
        }
      `,
    },
  ],
})
