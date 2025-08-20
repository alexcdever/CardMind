// Web应用主组件

import { DocumentProvider } from './contexts/DocumentContext';
import { SyncProvider } from './contexts/SyncContext';
import DocumentList from './components/DocumentList';
import DocumentEditor from './components/DocumentEditor';
import './App.css';

function App() {
  return (
    <DocumentProvider>
      <SyncProvider>
        <div className="app">
          <header className="app-header">
            <h1>CardMind - 分布式笔记</h1>
          </header>
          <main className="app-main">
            <aside className="sidebar">
              <DocumentList />
            </aside>
            <section className="editor-container">
              <DocumentEditor />
            </section>
          </main>
        </div>
      </SyncProvider>
    </DocumentProvider>
  );
}

export default App;