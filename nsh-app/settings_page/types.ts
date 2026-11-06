// 设置页类型（自 settings_page.tsx 纯结构拆出，声明逐字保留）。

export interface SettingsSource {
  getDeviceName(): Promise<string>;
  setDeviceName(name: string): Promise<boolean>;
  getSyncAllowed(): Promise<boolean>;
  setSyncAllowed(allowed: boolean): Promise<boolean>;
}
