# CardMind 编辑器静态站点

`web_view(url)` 指向的目录。约定 `web/dist/` 为 esbuild 产物输出目录：

- `index.html` — 站点入口，相对加载 `./dist/bundle.js`
- `src/index.ts` — esbuild 入口（现为骨架，Phase 3 挂 Tiptap）
- `dist/` — esbuild 产物（`npm run build:web` 生成，不入库）

构建：`npm run build:web`（esbuild `--bundle --minify` → `web/dist/bundle.js`）
