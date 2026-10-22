// CardMind 编辑器静态站点最小入口（骨架）。
// Phase 3 将在此挂载 Tiptap；本入口仅验证 esbuild 打包链。
const root = document.getElementById('editor') ?? document.body;
root.innerHTML = '<p>CardMind editor shell</p>';
