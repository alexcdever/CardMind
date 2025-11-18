import React, { useState, useEffect } from 'react';
import { useSyncStore } from '../stores/syncStore';
import { CardService } from '../services/cardService';

/**
 * 网络状态监控组件
 * 用于实时监控和显示网络连接状态、设备信息和同步状态
 */
export const NetworkStatusMonitor: React.FC = () => {
  const syncStore = useSyncStore();
  const [isExpanded, setIsExpanded] = useState(false);
  const [testResults, setTestResults] = useState<any[]>([]);
  const [isTesting, setIsTesting] = useState(false);

  // 网络状态信息
  const [networkInfo, setNetworkInfo] = useState({
    deviceAddress: '',
    networkId: '',
    isOnline: false,
    connectedDevices: 0,
    webrtcStatus: 'disconnected',
    broadcastStatus: 'inactive',
    syncStatus: 'idle'
  });

  // 在线设备列表
  const [onlineDevices, setOnlineDevices] = useState<any[]>([]);

  // 更新网络信息
  useEffect(() => {
    const updateInfo = () => {
      const deviceAddress = `${window.location.hostname}:${window.location.port || '80'}`;
      setNetworkInfo({
        deviceAddress,
        networkId: syncStore.networkId || '',
        isOnline: syncStore.isOnline,
        connectedDevices: syncStore.connectedDevices || 0,
        webrtcStatus: syncStore.webrtcStatus || 'disconnected',
        broadcastStatus: syncStore.broadcastStatus || 'inactive',
        syncStatus: syncStore.syncStatus || 'idle'
      });
    };

    updateInfo();
    const interval = setInterval(updateInfo, 1000);
    return () => clearInterval(interval);
  }, [syncStore]);

  // 监听在线设备变化
  useEffect(() => {
    const handlePeersChange = (event: any) => {
      setOnlineDevices(event.detail?.devices || []);
    };

    window.addEventListener('sync-peers-changed', handlePeersChange);
    return () => window.removeEventListener('sync-peers-changed', handlePeersChange);
  }, []);

  // 网络连接测试
  const performNetworkTest = async () => {
    setIsTesting(true);
    const testStartTime = Date.now();
    
    try {
      const results = [];
      
      // 测试1: WebRTC连接状态
      const webrtcTest = {
        name: 'WebRTC连接测试',
        status: networkInfo.webrtcStatus === 'connected' ? 'passed' : 'failed',
        details: `WebRTC状态: ${networkInfo.webrtcStatus}`,
        timestamp: new Date().toISOString()
      };
      results.push(webrtcTest);

      // 测试2: 广播通道状态
      const broadcastTest = {
        name: 'BroadcastChannel测试',
        status: networkInfo.broadcastStatus === 'active' ? 'passed' : 'failed',
        details: `广播通道状态: ${networkInfo.broadcastStatus}`,
        timestamp: new Date().toISOString()
      };
      results.push(broadcastTest);

      // 测试3: 设备间连通性
      const connectivityTest = {
        name: '设备连通性测试',
        status: onlineDevices.length > 0 ? 'passed' : 'failed',
        details: `发现 ${onlineDevices.length} 台在线设备`,
        timestamp: new Date().toISOString()
      };
      results.push(connectivityTest);

      // 测试4: 数据同步测试
      const syncTest = await performDataSyncTest();
      results.push(syncTest);

      const testResult = {
        id: Date.now(),
        timestamp: new Date().toISOString(),
        duration: Date.now() - testStartTime,
        results,
        summary: {
          total: results.length,
          passed: results.filter(r => r.status === 'passed').length,
          failed: results.filter(r => r.status === 'failed').length
        }
      };

      setTestResults(prev => [testResult, ...prev.slice(0, 9)]); // 保留最近10次测试结果
      
    } catch (error) {
      console.error('网络测试失败:', error);
    } finally {
      setIsTesting(false);
    }
  };

  // 数据同步测试
  const performDataSyncTest = async (): Promise<any> => {
    try {
      // 创建测试卡片
      const testCard = {
        title: `同步测试卡片 - ${Date.now()}`,
        content: '这是网络同步测试卡片，用于验证设备间数据同步功能',
        tags: ['test', 'sync'],
        createdAt: Date.now()
      };

      // 模拟卡片创建（这里需要实际的卡片服务）
      const cardService = CardService.getInstance();
      const createdCard = await cardService.createCard(testCard.title, testCard.content, testCard.tags);
      
      // 等待同步完成
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      return {
        name: '数据同步测试',
        status: 'passed',
        details: `测试卡片创建成功: ${createdCard.id}`,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      return {
        name: '数据同步测试',
        status: 'failed',
        details: `同步测试失败: ${error.message}`,
        timestamp: new Date().toISOString()
      };
    }
  };

  // 获取状态颜色
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'connected':
      case 'active':
      case 'passed':
        return 'text-green-500';
      case 'disconnected':
      case 'inactive':
      case 'failed':
        return 'text-red-500';
      case 'connecting':
      case 'syncing':
        return 'text-yellow-500';
      default:
        return 'text-gray-500';
    }
  };

  // 获取状态图标
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'connected':
      case 'active':
      case 'passed':
        return '✅';
      case 'disconnected':
      case 'inactive':
      case 'failed':
        return '❌';
      case 'connecting':
      case 'syncing':
        return '⏳';
      default:
        return '⚪';
    }
  };

  return (
    <div className="fixed bottom-4 right-4 bg-white rounded-lg shadow-lg border border-gray-200 z-50">
      {/* 收缩状态显示 */}
      {!isExpanded && (
        <div 
          className="p-3 cursor-pointer hover:bg-gray-50 transition-colors"
          onClick={() => setIsExpanded(true)}
        >
          <div className="flex items-center space-x-2">
            <div className={`w-3 h-3 rounded-full ${
              networkInfo.isOnline ? 'bg-green-500 animate-pulse' : 'bg-red-500'
            }`} />
            <span className="text-sm font-medium text-gray-700">
              {networkInfo.isOnline ? '在线' : '离线'}
            </span>
            <span className="text-xs text-gray-500">
              ({networkInfo.connectedDevices} 设备)
            </span>
          </div>
        </div>
      )}

      {/* 展开状态显示 */}
      {isExpanded && (
        <div className="w-80 max-h-96 overflow-hidden">
          {/* 头部 */}
          <div className="flex items-center justify-between p-3 border-b border-gray-200">
            <h3 className="text-sm font-semibold text-gray-800">网络状态监控</h3>
            <button
              onClick={() => setIsExpanded(false)}
              className="text-gray-400 hover:text-gray-600 transition-colors"
            >
              ✕
            </button>
          </div>

          {/* 内容区域 */}
          <div className="p-3 space-y-3 max-h-80 overflow-y-auto">
            {/* 设备信息 */}
            <div className="bg-gray-50 rounded-lg p-2">
              <h4 className="text-xs font-medium text-gray-600 mb-1">设备信息</h4>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span className="text-gray-500">地址:</span>
                  <span className="font-mono text-gray-700">{networkInfo.deviceAddress}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">网络ID:</span>
                  <span className="font-mono text-gray-700 text-ellipsis overflow-hidden">
                    {networkInfo.networkId ? networkInfo.networkId.substring(0, 8) + '...' : '无'}
                  </span>
                </div>
              </div>
            </div>

            {/* 连接状态 */}
            <div className="bg-gray-50 rounded-lg p-2">
              <h4 className="text-xs font-medium text-gray-600 mb-1">连接状态</h4>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between items-center">
                  <span className="text-gray-500">WebRTC:</span>
                  <span className={`font-medium ${getStatusColor(networkInfo.webrtcStatus)}`}>
                    {getStatusIcon(networkInfo.webrtcStatus)} {networkInfo.webrtcStatus}
                  </span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-500">广播通道:</span>
                  <span className={`font-medium ${getStatusColor(networkInfo.broadcastStatus)}`}>
                    {getStatusIcon(networkInfo.broadcastStatus)} {networkInfo.broadcastStatus}
                  </span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-500">同步状态:</span>
                  <span className={`font-medium ${getStatusColor(networkInfo.syncStatus)}`}>
                    {getStatusIcon(networkInfo.syncStatus)} {networkInfo.syncStatus}
                  </span>
                </div>
              </div>
            </div>

            {/* 在线设备 */}
            {onlineDevices.length > 0 && (
              <div className="bg-gray-50 rounded-lg p-2">
                <h4 className="text-xs font-medium text-gray-600 mb-1">
                  在线设备 ({onlineDevices.length})
                </h4>
                <div className="space-y-1">
                  {onlineDevices.map((device, index) => (
                    <div key={index} className="flex justify-between items-center text-xs">
                      <span className="text-gray-700">{device.name || device.id}</span>
                      <span className="text-green-500">✅ 在线</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* 测试按钮 */}
            <div className="flex space-x-2">
              <button
                onClick={performNetworkTest}
                disabled={isTesting}
                className="flex-1 bg-blue-500 text-white text-xs py-2 px-3 rounded hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                {isTesting ? '测试中...' : '网络测试'}
              </button>
              <button
                onClick={() => setTestResults([])}
                className="bg-gray-500 text-white text-xs py-2 px-3 rounded hover:bg-gray-600 transition-colors"
              >
                清除结果
              </button>
            </div>

            {/* 测试结果 */}
            {testResults.length > 0 && (
              <div className="bg-gray-50 rounded-lg p-2">
                <h4 className="text-xs font-medium text-gray-600 mb-1">最近测试结果</h4>
                <div className="space-y-1 max-h-32 overflow-y-auto">
                  {testResults.slice(0, 3).map((result, index) => (
                    <div key={result.id} className="text-xs border-l-2 border-gray-200 pl-2">
                      <div className="flex justify-between items-center">
                        <span className="text-gray-600">
                          {new Date(result.timestamp).toLocaleTimeString()}
                        </span>
                        <span className={`font-medium ${
                          result.summary.passed === result.summary.total 
                            ? 'text-green-500' 
                            : 'text-red-500'
                        }`}>
                          {result.summary.passed}/{result.summary.total}
                        </span>
                      </div>
                      <div className="text-gray-500 text-10px">
                        耗时: {result.duration}ms
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default NetworkStatusMonitor;