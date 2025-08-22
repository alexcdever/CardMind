import { DocumentProvider } from './contexts/DocumentContext';
import { SyncProvider } from './contexts/SyncContext';
import MainPage from './components/MainPage';
import './App.css';
import './components/BottomNavigation.css';
import './styles/global.css';

function App() {
  return (
    <DocumentProvider>
      <SyncProvider>
        <MainPage />
      </SyncProvider>
    </DocumentProvider>
  );
}

export default App;