module.exports = {
  root: true,
  env: {
    browser: true,
    es2020: true,
    node: true, // 添加对 Node.js 环境的支持
  },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react/recommended', // 添加 React 插件推荐规则
    'plugin:react-hooks/recommended',
    'plugin:import/errors',
    'plugin:import/warnings',
    'plugin:import/typescript',
    'plugin:jsx-a11y/recommended', // 添加可访问性插件推荐规则
    'plugin:prettier/recommended', // 添加 Prettier 插件推荐规则
  ],
  ignorePatterns: ['dist', '.eslintrc.js'],
  parser: '@typescript-eslint/parser',
  plugins: [
    '@typescript-eslint',
    'react',
    'react-refresh',
    'import',
    'jsx-a11y',
    'prettier',
  ],
  settings: {
    react: {
      version: 'detect', // 自动检测 React 版本
    },
    'import/resolver': {
      node: {
        extensions: ['.js', '.jsx', '.ts', '.tsx'],
        moduleDirectory: ['node_modules', 'src/'],
      },
    },
  },
  rules: {
    'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
    'react/react-in-jsx-scope': 'off', // 关闭此规则，因为 React 17+ 已经默认将 React 导入到 JSX 中
    'import/no-unresolved': 'error', // 确保导入的模块路径是正确的
    'import/named': 'error', // 确保命名导入是正确的
    'import/default': 'error', // 确保默认导入是正确的
    'import/namespace': 'error', // 确保命名空间导入是正确的
    'jsx-a11y/label-has-associated-control': ['error', { assert: 'either' }], // 确保标签与表单控件关联
    'jsx-a11y/anchor-is-valid': 'error', // 确保锚点链接是有效的
    'prettier/prettier': 'error', // 确保代码符合 Prettier 格式
  },
};