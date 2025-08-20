import { jsx as _jsx } from "react/jsx-runtime";
// Web应用入口文件 - 使用React 18
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './index.css';
const container = document.getElementById('root');
if (!container) {
    throw new Error('Root element not found');
}
const root = createRoot(container);
root.render(_jsx(React.StrictMode, { children: _jsx(App, {}) }));
//# sourceMappingURL=main.js.map