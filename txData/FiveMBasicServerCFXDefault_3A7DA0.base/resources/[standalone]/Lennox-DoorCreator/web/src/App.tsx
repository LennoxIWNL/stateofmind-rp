import { useState, useCallback, useEffect } from 'react';
import { ThemeProvider, useTheme } from './context/ThemeContext';
import { useNuiEvent } from './hooks/useNuiEvent';
import { useDoorData } from './hooks/useDoorData';
import { fetchNui } from './utils/nui';
import type {
  Page,
  InitData,
  Notification as NotifType,
  DetectedDoor,
  BulkUpdateData,
  DoorData,
} from './types';

import Header from './components/Header';
import Sidebar from './components/Sidebar';
import NotificationContainer from './components/Notification';
import ConfirmDialog from './components/ConfirmDialog';

import Dashboard from './pages/Dashboard';
import Creator from './pages/Creator';
import BulkCreator from './pages/BulkCreator';
import Buildings from './pages/Buildings';
import Templates from './pages/Templates';
import Import from './pages/Import';
import Backups from './pages/Backups';
import Logs from './pages/Logs';
import Settings from './pages/Settings';

const LENNOX_BRAND = 'Lennox Door Creator' as const;

function AppInner() {
  const [visible, setVisible] = useState(false);
  const [page, setPage] = useState<Page>('dashboard');
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [notifications, setNotifications] = useState<NotifType[]>([]);
  const [confirmDialog, setConfirmDialog] = useState<{
    open: boolean;
    title: string;
    message: string;
    onConfirm: () => void;
  }>({ open: false, title: '', message: '', onConfirm: () => {} });

  const [creatorMode, setCreatorMode] = useState(false);
  const [detectedDoor, setDetectedDoor] = useState<DetectedDoor | null>(null);
  const [editorData, setEditorData] = useState<(Partial<DoorData> & { modelName?: string; category?: string; isDouble?: boolean }) | null>(null);

  const [bulkMode, setBulkMode] = useState(false);
  const [bulkData, setBulkData] = useState<BulkUpdateData | null>(null);

  const { setThemeColor } = useTheme();
  const doorData = useDoorData();

  const addNotification = useCallback((type: NotifType['type'], message: string) => {
    const id = Math.random().toString(36).slice(2, 9);
    setNotifications((prev) => [...prev, { id, type, message }]);
    setTimeout(() => {
      setNotifications((prev) => prev.filter((n) => n.id !== id));
    }, 3000);
  }, []);

  const showConfirm = useCallback(
    (title: string, message: string, onConfirm: () => void) => {
      setConfirmDialog({ open: true, title, message, onConfirm });
    },
    []
  );

  useNuiEvent<InitData>('open', (data) => {
    setVisible(true);
    if (data.theme) setThemeColor(data.theme);
    doorData.initialize(data);
  });

  useNuiEvent('close', () => {
    setVisible(false);
    setCreatorMode(false);
    setBulkMode(false);
    setDetectedDoor(null);
    setEditorData(null);
    setBulkData(null);
  });

  useNuiEvent<{ active: boolean }>('creatorMode', (data) => {
    setCreatorMode(data.active);
    if (!data.active) {
      setDetectedDoor(null);
    }
  });

  useNuiEvent<DetectedDoor | null>('doorDetected', (data) => {
    setDetectedDoor(data);
  });

  useNuiEvent<Partial<DoorData> & { modelName?: string; category?: string; isDouble?: boolean }>('openEditor', (data) => {
    setEditorData(data);
    setCreatorMode(false);
    setPage('creator');
  });

  useNuiEvent<{ active: boolean; radius?: number }>('bulkMode', (data) => {
    setBulkMode(data.active);
    if (!data.active) setBulkData(null);
  });

  useNuiEvent<BulkUpdateData>('bulkUpdate', (data) => {
    setBulkData(data);
  });

  useNuiEvent<{ type: NotifType['type']; message: string }>('notification', (data) => {
    addNotification(data.type, data.message);
  });

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && visible) {
        fetchNui('close');
        setVisible(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [visible]);

  useEffect(() => {
    document.title = LENNOX_BRAND;
  }, []);

  if (!visible) return null;

  if (creatorMode) {
    return (
      <div className="fixed inset-0 flex items-start justify-center pt-4 pointer-events-none">
        <div className="glass rounded-xl p-4 w-80 pointer-events-auto animate-fade-in">
          <div className="text-center mb-3">
            <h3 className="text-sm font-semibold" style={{ color: 'var(--primary)' }}>
              Door Selection Mode
            </h3>
            <p className="text-xs text-gray-400 mt-1">Aim at a door and press Enter to select</p>
          </div>
          {detectedDoor ? (
            <div className="space-y-2 text-xs">
              <div className="flex justify-between">
                <span className="text-gray-400">Model</span>
                <span className="text-white font-mono">{detectedDoor.modelName}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Hash</span>
                <span className="text-white font-mono">{detectedDoor.model}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Category</span>
                <span className="capitalize" style={{ color: 'var(--primary)' }}>
                  {detectedDoor.category}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Position</span>
                <span className="text-white font-mono text-[10px]">
                  {detectedDoor.coords.x.toFixed(2)}, {detectedDoor.coords.y.toFixed(2)},{' '}
                  {detectedDoor.coords.z.toFixed(2)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Heading</span>
                <span className="text-white font-mono">{detectedDoor.heading.toFixed(2)}</span>
              </div>
            </div>
          ) : (
            <p className="text-xs text-gray-500 text-center py-4">No door detected — aim at a door object</p>
          )}
          <div className="mt-3 text-[10px] text-gray-500 text-center">
            ENTER = Select • BACKSPACE = Cancel/Skip
          </div>
        </div>
        <NotificationContainer notifications={notifications} />
      </div>
    );
  }

  const pageProps = {
    doors: doorData.doors,
    buildings: doorData.buildings,
    jobs: doorData.jobs,
    gangs: doorData.gangs,
    refresh: doorData.refresh,
    addNotification,
    showConfirm,
    editorData,
    setEditorData,
    bulkMode,
    bulkData,
  };

  return (
    <div className="fixed inset-0 flex items-center justify-center animate-fade-in">
      <div
        className="glass rounded-2xl overflow-hidden flex flex-col"
        style={{ width: '85vw', height: '80vh', maxWidth: 1400 }}
      >
        <Header onClose={() => fetchNui('close')} />
        <div className="flex flex-1 overflow-hidden">
          <Sidebar
            currentPage={page}
            onNavigate={setPage}
            collapsed={sidebarCollapsed}
            onToggleCollapse={() => setSidebarCollapsed(!sidebarCollapsed)}
          />
          <main className="flex-1 overflow-y-auto p-6">
            {page === 'dashboard' && <Dashboard doors={pageProps.doors} buildings={pageProps.buildings} refresh={pageProps.refresh} />}
            {page === 'creator' && <Creator doors={pageProps.doors} jobs={pageProps.jobs} gangs={pageProps.gangs} refresh={pageProps.refresh} addNotification={pageProps.addNotification} showConfirm={pageProps.showConfirm} editorData={pageProps.editorData} setEditorData={pageProps.setEditorData} />}
            {page === 'bulk' && <BulkCreator jobs={pageProps.jobs} gangs={pageProps.gangs} refresh={pageProps.refresh} addNotification={pageProps.addNotification} bulkMode={pageProps.bulkMode} bulkData={pageProps.bulkData} />}
            {page === 'buildings' && <Buildings buildings={pageProps.buildings} doors={pageProps.doors} jobs={pageProps.jobs} gangs={pageProps.gangs} refresh={pageProps.refresh} addNotification={pageProps.addNotification} showConfirm={pageProps.showConfirm} />}
            {page === 'templates' && <Templates addNotification={pageProps.addNotification} />}
            {page === 'import' && <Import refresh={pageProps.refresh} addNotification={pageProps.addNotification} />}
            {page === 'backups' && <Backups refresh={pageProps.refresh} addNotification={pageProps.addNotification} showConfirm={pageProps.showConfirm} />}
            {page === 'logs' && <Logs />}
            {page === 'settings' && <Settings />}
          </main>
        </div>
      </div>
      <NotificationContainer notifications={notifications} />
      <ConfirmDialog
        open={confirmDialog.open}
        title={confirmDialog.title}
        message={confirmDialog.message}
        onConfirm={() => {
          confirmDialog.onConfirm();
          setConfirmDialog((d) => ({ ...d, open: false }));
        }}
        onCancel={() => setConfirmDialog((d) => ({ ...d, open: false }))}
      />
    </div>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <AppInner />
    </ThemeProvider>
  );
}
