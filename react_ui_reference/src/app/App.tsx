import { useState, useEffect, useCallback } from 'react';
import { Button } from './components/ui/button';
import { Input } from './components/ui/input';
import { NoteCard, type Note } from './components/note-card';
import { DeviceManager, type Device } from './components/device-manager';
import { SyncStatus } from './components/sync-status';
import { MobileNav } from './components/mobile-nav';
import { NoteEditorFullscreen } from './components/note-editor-fullscreen';
import { SettingsPanel } from './components/settings-panel';
import { Plus, StickyNote, Search } from 'lucide-react';
import { Toaster } from './components/ui/sonner';
import { toast } from 'sonner';

const STORAGE_KEY = 'distributed-notes';
const DEVICES_KEY = 'paired-devices';
const CURRENT_DEVICE_KEY = 'current-device';

type ActiveTab = 'notes' | 'devices' | 'settings';

export default function App() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [currentDevice, setCurrentDevice] = useState<Device>(() => {
    const saved = localStorage.getItem(CURRENT_DEVICE_KEY);
    if (saved) {
      return JSON.parse(saved);
    }
    return {
      id: `device-${Date.now()}`,
      name: `我的设备 ${Math.floor(Math.random() * 1000)}`,
      type: 'laptop' as const,
      status: 'online' as const,
      lastSeen: Date.now(),
    };
  });
  const [pairedDevices, setPairedDevices] = useState<Device[]>(() => {
    const saved = localStorage.getItem(DEVICES_KEY);
    return saved ? JSON.parse(saved) : [];
  });
  const [lastSyncTime, setLastSyncTime] = useState(Date.now());
  const [isSyncing, setIsSyncing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState<ActiveTab>('notes');
  const [editingNote, setEditingNote] = useState<Note | null>(null);
  const [isEditorOpen, setIsEditorOpen] = useState(false);

  // 加载笔记
  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      setNotes(JSON.parse(saved));
    }
  }, []);

  // 保存笔记到 localStorage
  const saveNotes = useCallback((notesToSave: Note[]) => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(notesToSave));
    setLastSyncTime(Date.now());
  }, []);

  // 使用 BroadcastChannel 实现跨标签页同步
  useEffect(() => {
    const channel = new BroadcastChannel('notes-sync');

    channel.onmessage = (event) => {
      if (event.data.type === 'notes-update') {
        setIsSyncing(true);
        setNotes(event.data.notes);
        toast.success(`收到来自 ${event.data.deviceName} 的同步数据`);
        setTimeout(() => {
          setIsSyncing(false);
          setLastSyncTime(Date.now());
        }, 500);
      } else if (event.data.type === 'device-update') {
        setPairedDevices((prev) => {
          const exists = prev.find((d) => d.id === event.data.device.id);
          if (exists) {
            return prev.map((d) =>
              d.id === event.data.device.id ? event.data.device : d
            );
          }
          return [...prev, event.data.device];
        });
      }
    };

    return () => channel.close();
  }, []);

  // 广播笔记更新
  const broadcastNotesUpdate = useCallback(
    (updatedNotes: Note[]) => {
      const channel = new BroadcastChannel('notes-sync');
      channel.postMessage({
        type: 'notes-update',
        notes: updatedNotes,
        deviceName: currentDevice.name,
        timestamp: Date.now(),
      });
      channel.close();
    },
    [currentDevice.name]
  );

  // 添加笔记
  const handleAddNote = () => {
    const newNote: Note = {
      id: `note-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      title: '',
      content: '',
      tags: [],
      createdAt: Date.now(),
      updatedAt: Date.now(),
      lastEditDevice: currentDevice.name,
      isEditing: false,
    };
    const updatedNotes = [newNote, ...notes];
    setNotes(updatedNotes);
    saveNotes(updatedNotes);
    broadcastNotesUpdate(updatedNotes);
    
    // 移动端打开全屏编辑器
    setEditingNote(newNote);
    setIsEditorOpen(true);
    toast.success('创建新笔记');
  };

  // 更新笔记
  const handleUpdateNote = (updatedNote: Note) => {
    const updatedNotes = notes.map((note) =>
      note.id === updatedNote.id ? updatedNote : note
    );
    setNotes(updatedNotes);
    saveNotes(updatedNotes);
    broadcastNotesUpdate(updatedNotes);
    toast.success('笔记已更新');
  };

  // 删除笔记
  const handleDeleteNote = (id: string) => {
    const updatedNotes = notes.filter((note) => note.id !== id);
    setNotes(updatedNotes);
    saveNotes(updatedNotes);
    broadcastNotesUpdate(updatedNotes);
    toast.success('笔记已删除');
  };

  // 设备管理
  const handleDeviceNameChange = (name: string) => {
    const updated = { ...currentDevice, name };
    setCurrentDevice(updated);
    localStorage.setItem(CURRENT_DEVICE_KEY, JSON.stringify(updated));
    
    const channel = new BroadcastChannel('notes-sync');
    channel.postMessage({
      type: 'device-update',
      device: updated,
    });
    channel.close();
  };

  const handleAddDevice = (device: Device) => {
    const updated = [...pairedDevices, device];
    setPairedDevices(updated);
    localStorage.setItem(DEVICES_KEY, JSON.stringify(updated));
    toast.success(`设备 ${device.name} 已配对`);
  };

  const handleRemoveDevice = (deviceId: string) => {
    const updated = pairedDevices.filter((d) => d.id !== deviceId);
    setPairedDevices(updated);
    localStorage.setItem(DEVICES_KEY, JSON.stringify(updated));
    toast.success('设备已移除');
  };

  // 过滤笔记
  const filteredNotes = notes.filter(
    (note) =>
      note.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      note.content.toLowerCase().includes(searchQuery.toLowerCase()) ||
      note.tags.some((tag) => tag.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  return (
    <div className="min-h-screen bg-background pb-20 lg:pb-0">
      <Toaster />
      
      {/* 全屏编辑器 (移动端) */}
      <NoteEditorFullscreen
        note={editingNote}
        currentDevice={currentDevice.name}
        isOpen={isEditorOpen}
        onClose={() => setIsEditorOpen(false)}
        onSave={handleUpdateNote}
      />
      
      {/* 顶部导航 */}
      <header className="sticky top-0 z-40 bg-background/80 backdrop-blur-lg border-b">
        <div className="container mx-auto px-4 py-3 lg:py-4">
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <StickyNote className="size-6 lg:size-8 text-primary" />
              <div>
                <h1 className="text-lg lg:text-2xl font-bold">分布式笔记</h1>
                <p className="text-xs lg:text-sm text-muted-foreground hidden sm:block">
                  多设备协同 · 局域网同步
                </p>
              </div>
            </div>
            <div className="hidden lg:flex items-center gap-3">
              <SyncStatus
                lastSyncTime={lastSyncTime}
                isSyncing={isSyncing}
              />
              <Button onClick={handleAddNote} className="gap-2">
                <Plus className="size-4" />
                新建笔记
              </Button>
            </div>
          </div>
        </div>
      </header>

      {/* 主内容区 */}
      <main className="container mx-auto px-4 py-4 lg:py-6">
        {/* 桌面端布局 */}
        <div className="hidden lg:grid lg:grid-cols-3 gap-6">
          {/* 左侧：设备管理 */}
          <div className="lg:col-span-1 space-y-4">
            <DeviceManager
              currentDevice={currentDevice}
              pairedDevices={pairedDevices}
              onDeviceNameChange={handleDeviceNameChange}
              onAddDevice={handleAddDevice}
              onRemoveDevice={handleRemoveDevice}
            />
            <SettingsPanel />
          </div>

          {/* 右侧：笔记列表 */}
          <div className="lg:col-span-2 space-y-4">
            {/* 搜索栏 */}
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
              <Input
                placeholder="搜索笔记标题、内容或标签..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>

            {/* 笔记网格 */}
            {filteredNotes.length === 0 ? (
              <div className="text-center py-16">
                <StickyNote className="size-16 mx-auto mb-4 text-muted-foreground opacity-50" />
                <p className="text-muted-foreground mb-4">
                  {searchQuery ? '没有找到匹配的笔记' : '还没有笔记'}
                </p>
                {!searchQuery && (
                  <Button onClick={handleAddNote} variant="outline">
                    <Plus className="size-4 mr-2" />
                    创建第一条笔记
                  </Button>
                )}
              </div>
            ) : (
              <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
                {filteredNotes.map((note) => (
                  <div
                    key={note.id}
                    onClick={() => {
                      setEditingNote(note);
                      setIsEditorOpen(true);
                    }}
                  >
                    <NoteCard
                      note={note}
                      currentDevice={currentDevice.name}
                      onUpdate={handleUpdateNote}
                      onDelete={handleDeleteNote}
                    />
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* 移动端布局 */}
        <div className="lg:hidden">
          {/* 笔记标签页 */}
          {activeTab === 'notes' && (
            <div className="space-y-4">
              {/* 搜索栏 */}
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
                <Input
                  placeholder="搜索笔记..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>

              {/* 笔记列表 */}
              {filteredNotes.length === 0 ? (
                <div className="text-center py-16">
                  <StickyNote className="size-16 mx-auto mb-4 text-muted-foreground opacity-50" />
                  <p className="text-muted-foreground mb-4">
                    {searchQuery ? '没有找到匹配的笔记' : '还没有笔记'}
                  </p>
                </div>
              ) : (
                <div className="space-y-3">
                  {filteredNotes.map((note) => (
                    <div
                      key={note.id}
                      onClick={() => {
                        setEditingNote(note);
                        setIsEditorOpen(true);
                      }}
                    >
                      <NoteCard
                        note={note}
                        currentDevice={currentDevice.name}
                        onUpdate={handleUpdateNote}
                        onDelete={handleDeleteNote}
                      />
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* 设备标签页 */}
          {activeTab === 'devices' && (
            <DeviceManager
              currentDevice={currentDevice}
              pairedDevices={pairedDevices}
              onDeviceNameChange={handleDeviceNameChange}
              onAddDevice={handleAddDevice}
              onRemoveDevice={handleRemoveDevice}
            />
          )}

          {/* 设置标签页 */}
          {activeTab === 'settings' && <SettingsPanel />}
        </div>
      </main>

      {/* 移动端浮动按钮 */}
      <Button
        onClick={handleAddNote}
        size="lg"
        className="fixed bottom-20 right-4 lg:hidden size-14 rounded-full shadow-lg"
      >
        <Plus className="size-6" />
      </Button>

      {/* 移动端底部导航 */}
      <MobileNav
        activeTab={activeTab}
        onTabChange={setActiveTab}
        noteCount={notes.length}
        deviceCount={pairedDevices.length}
      />

      {/* 开发提示 */}
      <div className="hidden lg:block fixed bottom-4 left-4 max-w-xs">
        <div className="bg-muted/80 backdrop-blur-sm rounded-lg p-3 text-xs text-muted-foreground border">
          <p className="font-medium mb-1">💡 UI 原型参考</p>
          <p>这是 Flutter 开发的设计参考</p>
          <p className="mt-1">- 移动端: 底部导航 + 全屏编辑</p>
          <p>- 桌面端: 侧边栏 + 多栏布局</p>
        </div>
      </div>
    </div>
  );
}