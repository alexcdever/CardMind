// 设置管理器 - 使用Zustand和Yjs管理应用设置
import { create } from 'zustand';
import * as Y from 'yjs';
import { AppSettings, RelaySettings, defaultSettings } from '../types/settings';

interface SettingsState {
  settings: AppSettings;
  yDoc: Y.Doc;
  settingsMap: Y.Map<any>;
  isInitialized: boolean;
  
  // 操作方法
  initializeSettings: (yDoc: Y.Doc) => void;
  updateRelaySettings: (relay: Partial<RelaySettings>) => void;
  updateSettings: (settings: Partial<AppSettings>) => void;
  getRelayEndpoint: () => string | null;
}

export const useSettingsManager = create<SettingsState>((set, get) => ({
  settings: { ...defaultSettings },
  yDoc: new Y.Doc(),
  settingsMap: new Y.Map(),
  isInitialized: false,

  // 初始化设置 - 防止覆盖现有配置
  initializeSettings: (yDoc: Y.Doc) => {
    const settingsMap = yDoc.getMap('settings');
    
    // 检查是否已存在配置
    const existingSettings = settingsMap.get('appSettings') as AppSettings;
    let mergedSettings = { ...defaultSettings };
    
    if (existingSettings) {
      // 合并现有配置，防止覆盖
      mergedSettings = {
        ...defaultSettings,
        ...existingSettings,
        relay: {
          ...defaultSettings.relay,
          ...(existingSettings.relay || {})
        },
        lastUpdated: new Date()
      };
    }
    
    // 保存合并后的配置
    settingsMap.set('appSettings', mergedSettings);
    
    // 监听配置变更
    settingsMap.observe(() => {
      const updatedSettings = settingsMap.get('appSettings') as AppSettings;
      if (updatedSettings) {
        set({ settings: updatedSettings });
      }
    });

    set({
      yDoc,
      settingsMap,
      settings: mergedSettings,
      isInitialized: true
    });
  },

  // 更新中继服务配置
  updateRelaySettings: (relay: Partial<RelaySettings>) => {
    const { settings, settingsMap } = get();
    const newSettings = {
      ...settings,
      relay: {
        ...settings.relay,
        ...relay
      },
      lastUpdated: new Date()
    };
    
    settingsMap.set('appSettings', newSettings);
    set({ settings: newSettings });
  },

  // 更新整体配置
  updateSettings: (settings: Partial<AppSettings>) => {
    const { settingsMap } = get();
    const currentSettings = get().settings;
    const newSettings = {
      ...currentSettings,
      ...settings,
      lastUpdated: new Date()
    };
    
    settingsMap.set('appSettings', newSettings);
    set({ settings: newSettings });
  },

  // 获取中继服务端点
  getRelayEndpoint: () => {
    const { settings } = get();
    if (!settings.relay.enabled) {
      return null;
    }
    
    const { ip, port, path } = settings.relay;
    return `ws://${ip}:${port}${path}`;
  }
}));