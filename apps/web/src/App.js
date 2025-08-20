import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { DocumentProvider } from './contexts/DocumentContext';
import { SyncProvider } from './contexts/SyncContext';
import DocumentList from './components/DocumentList';
import DocumentEditor from './components/DocumentEditor';
import './App.css';
function App() {
    return (_jsx(DocumentProvider, { children: _jsx(SyncProvider, { children: _jsxs("div", { className: "app", children: [_jsx("header", { className: "app-header", children: _jsx("h1", { children: "CardMind - \u5206\u5E03\u5F0F\u7B14\u8BB0" }) }), _jsxs("main", { className: "app-main", children: [_jsx("aside", { className: "sidebar", children: _jsx(DocumentList, {}) }), _jsx("section", { className: "editor-container", children: _jsx(DocumentEditor, {}) })] })] }) }) }));
}
export default App;
//# sourceMappingURL=App.js.map