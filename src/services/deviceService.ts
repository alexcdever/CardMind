/**
 * 设备管理服务
 * 提供设备相关的业务逻辑和数据操作
 */

import { v4 as uuidv4 } from 'uuid';
import { getDeviceData, saveDeviceData } from './localStorageService';

export interface DeviceInfo {
  id: string;
  nickname: string;
  deviceType: string;
  lastSeen: number;
}

export interface DeviceServiceInterface {
  // 设备初始化
  initializeDevice(): Promise<DeviceInfo>;
  
  // 设备信息管理
  getDeviceInfo(): DeviceInfo;
  updateNickname(nickname: string): void;
  updateLastSeen(): void;
  
  // 设备类型检测
  getDeviceType(): string;
  
  // 在线设备管理
  getOnlineDevices(): DeviceInfo[];
  updateOnlineDevices(devices: DeviceInfo[]): void;
  
  // 设备状态
  isDeviceOnline(): boolean;
}

class DeviceService implements DeviceServiceInterface {
  private currentDevice: DeviceInfo | null = null;

  /**
   * 初始化设备信息
   */
  async initializeDevice(): Promise<DeviceInfo> {
    try {
      // 尝试从本地存储获取设备信息
      const storedDevice = getDeviceData<DeviceInfo | null>(null);
      
      if (storedDevice) {
        this.currentDevice = storedDevice;
        return storedDevice;
      }

      // 生成新的设备信息
      const deviceType = this.getDeviceType();
      const nickname = this.generateDefaultNickname(deviceType);
      const deviceInfo: DeviceInfo = {
        id: uuidv4(),
        nickname,
        deviceType,
        lastSeen: Date.now()
      };

      this.currentDevice = deviceInfo;
      saveDeviceData(deviceInfo);
      
      return deviceInfo;
    } catch (error) {
      console.error('初始化设备失败:', error);
      throw new Error('初始化设备失败');
    }
  }

  /**
   * 获取当前设备信息
   */
  getDeviceInfo(): DeviceInfo {
    if (!this.currentDevice) {
      throw new Error('设备未初始化');
    }
    return this.currentDevice;
  }

  /**
   * 更新设备昵称
   */
  updateNickname(nickname: string): void {
    if (!this.currentDevice) {
      throw new Error('设备未初始化');
    }

    this.currentDevice.nickname = nickname;
    this.currentDevice.lastSeen = Date.now();
    saveDeviceData(this.currentDevice);
  }

  /**
   * 更新最后在线时间
   */
  updateLastSeen(): void {
    if (!this.currentDevice) {
      throw new Error('设备未初始化');
    }

    this.currentDevice.lastSeen = Date.now();
    saveDeviceData(this.currentDevice);
  }

  /**
   * 获取设备类型
   */
  getDeviceType(): string {
    const ua = navigator.userAgent;
    if (ua.match(/iPad/i) || ua.match(/iPhone/i) || ua.match(/Android/i)) {
      return 'mobile';
    }
    if (ua.match(/Win/i) || ua.match(/Mac/i) || ua.match(/Linux/i)) {
      return 'desktop';
    }
    return 'unknown';
  }

  /**
   * 获取在线设备列表
   */
  getOnlineDevices(): DeviceInfo[] {
    // 这里应该从同步服务获取在线设备信息
    // 暂时返回空数组，实际实现需要与syncService集成
    return [];
  }

  /**
   * 更新在线设备列表
   */
  updateOnlineDevices(devices: DeviceInfo[]): void {
    // 这里应该更新本地存储的在线设备信息
    // 实际实现需要与syncService集成
    console.log('更新在线设备列表:', devices);
  }

  /**
   * 检查设备是否在线
   */
  isDeviceOnline(): boolean {
    return navigator.onLine;
  }

  /**
   * 生成默认设备昵称
   */
  private generateDefaultNickname(deviceType: string): string {
    const typeName = deviceType === 'mobile' ? '移动设备' : '桌面设备';
    return `${typeName}-${Math.floor(Math.random() * 10000)}`;
  }
}

// 导出单例实例
export default new DeviceService();