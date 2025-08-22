// 应用设置相关的TypeScript类型定义

export interface RelaySettings {
  enabled: boolean;        // 中继服务开关
  ip: string;             // 中继服务IP地址
  port: number;           // 中继服务端口号
  path: string;           // 中继服务路径
}

export interface AppSettings {
  relay: RelaySettings;   // 中继服务配置
  lastUpdated: Date;      // 最后更新时间
  version: string;        // 配置版本号
}

// 默认配置
export const defaultSettings: AppSettings = {
  relay: {
    enabled: false,
    ip: 'localhost',
    port: 8080,
    path: '/relay'
  },
  lastUpdated: new Date(),
  version: '1.0.0'
};

// 设置变更事件类型
export type SettingsChangeHandler = (settings: AppSettings) => void;