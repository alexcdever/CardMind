/**
 * 认证服务
 * 提供Access Code生成、验证和网络管理功能
 */

import { v4 as uuidv4 } from 'uuid';
import { getAuthData, saveAuthData, clearAuthData } from './localStorageService';

export interface AuthData {
  networkId: string;
  isAuthenticated: boolean;
  lastSyncTimestamp: number;
}

export interface NetworkInfo {
  address: string;
  timestamp: number;
  randomCode: string;
}

export interface AuthServiceInterface {
  // 网络ID生成和验证
  generateNetworkId(): string;
  validateNetworkId(networkId: string): boolean;
  extractNetworkInfo(networkId: string): NetworkInfo | null;
  
  // 网络管理
  joinNetwork(networkId: string): Promise<boolean>;
  leaveNetwork(): void;
  getCurrentNetworkId(): string | null;
  isAuthenticated(): boolean;
  
  // 设备地址获取
  getDeviceAddress(): string;
}

class AuthService implements AuthServiceInterface {
  private currentAuth: AuthData | null = null;

  constructor() {
    this.loadAuthData();
  }

  /**
   * 从本地存储加载认证数据
   */
  private loadAuthData(): void {
    try {
      const authData = getAuthData<AuthData | null>(null);
      this.currentAuth = authData;
    } catch (error) {
      console.error('加载认证数据失败:', error);
      this.currentAuth = null;
    }
  }

  /**
   * 保存认证数据到本地存储
   */
  private saveAuthData(): void {
    if (this.currentAuth) {
      saveAuthData(this.currentAuth);
    }
  }

  /**
   * 生成新的网络ID
   */
  generateNetworkId(): string {
    const deviceAddress = this.getDeviceAddress();
    const randomCode = uuidv4().replace(/-/g, ''); // 移除UUID中的连字符
    const timestamp = Date.now();

    // 组合数据：设备地址 + 时间戳 + 随机码
    const rawData = JSON.stringify({
      address: deviceAddress,
      timestamp,
      randomCode
    });

    // 使用Base64编码生成最终网络ID
    return this.encodeBase64(rawData);
  }

  /**
   * 验证网络ID格式
   */
  validateNetworkId(networkId: string): boolean {
    try {
      // 尝试解码网络ID
      const decoded = this.decodeBase64(networkId);
      const data = JSON.parse(decoded);

      // 验证解码后的数据结构
      return !!(
        data.address && typeof data.address === 'string' &&
        data.timestamp && typeof data.timestamp === 'number' &&
        data.randomCode && typeof data.randomCode === 'string' &&
        data.randomCode.length === 32 // UUID去掉连字符后的长度
      );
    } catch {
      // 解码失败或数据结构不正确
      return false;
    }
  }

  /**
   * 从网络ID提取网络信息
   */
  extractNetworkInfo(networkId: string): NetworkInfo | null {
    try {
      const decoded = this.decodeBase64(networkId);
      const data = JSON.parse(decoded);

      if (data.address && data.timestamp && data.randomCode) {
        return {
          address: data.address,
          timestamp: data.timestamp,
          randomCode: data.randomCode
        };
      }
      return null;
    } catch (error) {
      console.error('解析网络ID失败:', error);
      return null;
    }
  }

  /**
   * 加入网络
   */
  async joinNetwork(networkId: string): Promise<boolean> {
    try {
      // 验证网络ID格式
      if (!this.validateNetworkId(networkId)) {
        console.error('网络ID格式验证失败:', networkId);
        return false;
      }

      console.log('网络ID格式验证通过');

      // 保存网络ID到本地存储
      this.currentAuth = {
        networkId: networkId,
        isAuthenticated: true,
        lastSyncTimestamp: Date.now()
      };

      this.saveAuthData();
      console.log('成功加入网络:', networkId);
      return true;

    } catch (error) {
      console.error('加入网络时出错:', error);
      return false;
    }
  }

  /**
   * 离开网络
   */
  leaveNetwork(): void {
    try {
      // 清除认证数据
      this.currentAuth = null;

      clearAuthData();
      console.log('已离开网络');
    } catch (error) {
      console.error('离开网络失败:', error);
    }
  }

  /**
   * 获取当前网络ID
   */
  getCurrentNetworkId(): string | null {
    return this.currentAuth?.networkId || null;
  }

  /**
   * 检查是否已认证
   */
  isAuthenticated(): boolean {
    return this.currentAuth?.isAuthenticated || false;
  }

  /**
   * 获取设备地址
   */
  getDeviceAddress(): string {
    try {
      // 优先使用window.location，如果可用的话
      const { protocol, hostname, port } = window.location;
      const effectivePort = port || (protocol === 'https:' ? '443' : '80');
      return `${hostname}:${effectivePort}`;
    } catch (error) {
      // 如果在测试环境或window.location不可用，使用默认值
      return 'localhost:80';
    }
  }

  /**
   * Base64编码（URL安全）
   */
  private encodeBase64(text: string): string {
    return btoa(encodeURIComponent(text))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

  /**
   * Base64解码
   */
  private decodeBase64(encoded: string): string {
    try {
      const padded = encoded + '='.repeat((4 - encoded.length % 4) % 4);
      return decodeURIComponent(atob(padded.replace(/-/g, '+').replace(/_/g, '/')));
    } catch {
      return '';
    }
  }
}

// 导出单例实例
export default new AuthService();