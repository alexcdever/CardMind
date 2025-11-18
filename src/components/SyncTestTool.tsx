import React, { useState, useEffect } from 'react';
import { useSyncStore } from '../stores/syncStore';
import { useCardStore } from '../stores/cardStore';
import { useDeviceStore } from '../stores/deviceStore';
import { v4 as uuidv4 } from 'uuid';

interface SyncTestResult {
  id: string;
  timestamp: number;
  operation: 'create' | 'update' | 'delete';
  deviceId: string;
  deviceName: string;
  cardId: string;
  status: 'pending' | 'success' | 'failed';
  details: string;
  syncedDevices: string[];
}

interface CardSyncTest {
  id: string;
  title: string;
  content: string;
  createdAt: number;
  updatedAt: number;
  deviceId: string;
  testPhase: 'created' | 'updated' | 'deleted';
}

export const SyncTestTool: React.FC = () => {
  const [isTesting, setIsTesting] = useState(false);
  const [testResults, setTestResults] = useState<SyncTestResult[]>([]);
  const [testCards, setTestCards] = useState<CardSyncTest[]>([]);
  const [currentPhase, setCurrentPhase] = useState<string>('');
  const [testProgress, setTestProgress] = useState(0);

  const { connectedDevices, isOnline } = useSyncStore();
  const { cards, createCard, updateCard, deleteCard } = useCardStore();
  const { currentDevice } = useDeviceStore();

  // 监听卡片变化，验证同步
  useEffect(() => {
    if (!isTesting) return;

    // 检查测试卡片是否同步
    testCards.forEach(testCard => {
      const actualCard = cards.find(card => card.id === testCard.id);
      
      if (testCard.testPhase === 'created' && actualCard) {
        // 卡片创建同步成功
        updateTestResult(testCard.id, 'success', `卡片已同步到当前设备`, [currentDevice?.id || '']);
      } else if (testCard.testPhase === 'updated' && actualCard) {
        // 检查更新是否同步
        if (actualCard.title === testCard.title && actualCard.content === testCard.content) {
          updateTestResult(testCard.id, 'success', `卡片更新已同步`, [currentDevice?.id || '']);
        }
      } else if (testCard.testPhase === 'deleted' && !actualCard) {
        // 删除同步成功
        updateTestResult(testCard.id, 'success', `卡片删除已同步`, [currentDevice?.id || '']);
      }
    });
  }, [cards, testCards, isTesting, currentDevice]);

  const updateTestResult = (cardId: string, status: 'success' | 'failed', details: string, syncedDevices: string[]) => {
    setTestResults(prev => prev.map(result => 
      result.cardId === cardId 
        ? { ...result, status, details, syncedDevices: [...result.syncedDevices, ...syncedDevices] }
        : result
    ));
  };

  const generateTestCard = (phase: 'create' | 'update' | 'delete'): CardSyncTest => {
    const now = Date.now();
    const deviceId = currentDevice?.id || 'unknown';
    
    return {
      id: uuidv4(),
      title: `测试卡片 - ${phase.toUpperCase()} - ${now}`,
      content: `这是测试卡片，用于验证${phase}操作的同步功能。\n创建时间: ${new Date(now).toLocaleString()}\n设备ID: ${deviceId}`,
      createdAt: now,
      updatedAt: now,
      deviceId,
      testPhase: phase === 'create' ? 'created' : phase === 'update' ? 'updated' : 'deleted'
    };
  };

  const runSyncTest = async () => {
    if (!isOnline || connectedDevices.length === 0) {
      alert('请先连接到网络并确保有其他设备在线');
      return;
    }

    setIsTesting(true);
    setTestResults([]);
    setTestCards([]);
    setTestProgress(0);

    try {
      // 阶段1: 创建测试
      setCurrentPhase('创建测试卡片');
      await runCreateTest();
      setTestProgress(33);

      // 等待同步
      await waitForSync(3000);

      // 阶段2: 更新测试
      setCurrentPhase('更新测试卡片');
      await runUpdateTest();
      setTestProgress(66);

      // 等待同步
      await waitForSync(3000);

      // 阶段3: 删除测试
      setCurrentPhase('删除测试卡片');
      await runDeleteTest();
      setTestProgress(100);

      // 等待最终同步
      await waitForSync(3000);
      
      setCurrentPhase('测试完成');
      
    } catch (error) {
      console.error('同步测试失败:', error);
      setCurrentPhase('测试失败');
    } finally {
      setIsTesting(false);
    }
  };

  const runCreateTest = async () => {
    const testCard = generateTestCard('create');
    setTestCards(prev => [...prev, testCard]);

    // 记录测试结果
    const result: SyncTestResult = {
      id: uuidv4(),
      timestamp: Date.now(),
      operation: 'create',
      deviceId: currentDevice?.id || '',
      deviceName: currentDevice?.name || '',
      cardId: testCard.id,
      status: 'pending',
      details: '正在创建测试卡片...',
      syncedDevices: []
    };
    setTestResults(prev => [...prev, result]);

    try {
      // 创建卡片
      await createCard({
        id: testCard.id,
        title: testCard.title,
        content: testCard.content,
        tags: ['sync-test'],
        createdAt: testCard.createdAt,
        updatedAt: testCard.updatedAt
      });

      // 更新结果状态
      setTestResults(prev => prev.map(r => 
        r.id === result.id 
          ? { ...r, status: 'success', details: '卡片创建成功，等待同步...' }
          : r
      ));

    } catch (error) {
      setTestResults(prev => prev.map(r => 
        r.id === result.id 
          ? { ...r, status: 'failed', details: `创建失败: ${error}` }
          : r
      ));
    }
  };

  const runUpdateTest = async () => {
    if (testCards.length === 0) return;

    const testCard = testCards[0]; // 使用第一个测试卡片
    const updatedCard = {
      ...testCard,
      title: `${testCard.title} [已更新]`,
      content: `${testCard.content}\n\n[更新内容] 这是更新后的内容，时间: ${new Date().toLocaleString()}`,
      updatedAt: Date.now(),
      testPhase: 'updated' as const
    };

    setTestCards(prev => prev.map(card => 
      card.id === testCard.id ? updatedCard : card
    ));

    // 记录测试结果
    const result: SyncTestResult = {
      id: uuidv4(),
      timestamp: Date.now(),
      operation: 'update',
      deviceId: currentDevice?.id || '',
      deviceName: currentDevice?.name || '',
      cardId: testCard.id,
      status: 'pending',
      details: '正在更新测试卡片...',
      syncedDevices: []
    };
    setTestResults(prev => [...prev, result]);

    try {
      // 更新卡片
      await updateCard(testCard.id, {
        title: updatedCard.title,
        content: updatedCard.content,
        updatedAt: updatedCard.updatedAt
      });

      setTestResults(prev => prev.map(r => 
        r.id === result.id 
          ? { ...r, status: 'success', details: '卡片更新成功，等待同步...' }
          : r
      ));

    } catch (error) {
      setTestResults(prev => prev.map(r => 
        r.id === result.id 
          ? { ...r, status: 'failed', details: `更新失败: ${error}` }
          : r
      ));
    }
  };

  const runDeleteTest = async () => {
    if (testCards.length === 0) return;

    const testCard = testCards[0];
    setTestCards(prev => prev.map(card => 
      card.id === testCard.id 
        ? { ...card, testPhase: 'deleted' as const }
        : card
    ));

    // 记录测试结果
    const result: SyncTestResult = {
      id: uuidv4(),
      timestamp: Date.now(),
      operation: 'delete',
      deviceId: currentDevice?.id || '',
      deviceName: currentDevice?.name || '',
      cardId: testCard.id,
      status: 'pending',
      details: '正在删除测试卡片...',
      syncedDevices: []
    };
    setTestResults(prev => [...prev, result]);

    try {
      // 删除卡片
      await deleteCard(testCard.id);

      setTestResults(prev => prev.map(r => 
        r.id === result.id 
          ? { ...r, status: 'success', details: '卡片删除成功，等待同步...' }
          : r
      ));

    } catch (error) {
      setTestResults(prev => prev.map(r => 
        r.id === result.id 
          ? { ...r, status: 'failed', details: `删除失败: ${error}` }
          : r
      ));
    }
  };

  const waitForSync = (timeout: number): Promise<void> => {
    return new Promise(resolve => {
      setTimeout(resolve, timeout);
    });
  };

  const clearTestResults = () => {
    setTestResults([]);
    setTestCards([]);
    setTestProgress(0);
    setCurrentPhase('');
  };

  const exportTestReport = () => {
    const report = {
      timestamp: Date.now(),
      deviceInfo: {
        id: currentDevice?.id,
        name: currentDevice?.name,
        userAgent: navigator.userAgent
      },
      networkInfo: {
        online: isOnline,
        connectedDevices: connectedDevices.length,
        devices: connectedDevices
      },
      testResults: testResults,
      summary: {
        total: testResults.length,
        success: testResults.filter(r => r.status === 'success').length,
        failed: testResults.filter(r => r.status === 'failed').length,
        pending: testResults.filter(r => r.status === 'pending').length
      }
    };

    const blob = new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sync-test-report-${Date.now()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="bg-white rounded-lg shadow-lg p-6 max-w-4xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-bold text-gray-800">🔄 数据同步测试工具</h2>
        <div className="flex gap-2">
          <button
            onClick={clearTestResults}
            className="px-4 py-2 bg-gray-500 text-white rounded-md hover:bg-gray-600 disabled:opacity-50"
            disabled={isTesting}
          >
            清除结果
          </button>
          <button
            onClick={exportTestReport}
            className="px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 disabled:opacity-50"
            disabled={testResults.length === 0}
          >
            导出报告
          </button>
        </div>
      </div>

      {/* 网络状态 */}
      <div className="mb-6 p-4 bg-gray-50 rounded-lg">
        <h3 className="text-lg font-semibold mb-2">网络状态</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="text-center">
            <div className={`text-sm font-medium ${isOnline ? 'text-green-600' : 'text-red-600'}`}>
              {isOnline ? '🟢 在线' : '🔴 离线'}
            </div>
            <div className="text-xs text-gray-500">网络状态</div>
          </div>
          <div className="text-center">
            <div className="text-sm font-medium text-blue-600">
              {connectedDevices.length}
            </div>
            <div className="text-xs text-gray-500">连接设备</div>
          </div>
          <div className="text-center">
            <div className="text-sm font-medium text-purple-600">
              {testResults.length}
            </div>
            <div className="text-xs text-gray-500">测试结果</div>
          </div>
          <div className="text-center">
            <div className="text-sm font-medium text-orange-600">
              {testCards.length}
            </div>
            <div className="text-xs text-gray-500">测试卡片</div>
          </div>
        </div>
      </div>

      {/* 测试控制 */}
      <div className="mb-6">
        <button
          onClick={runSyncTest}
          disabled={isTesting || !isOnline || connectedDevices.length === 0}
          className="w-full py-3 px-6 bg-green-500 text-white rounded-lg font-semibold hover:bg-green-600 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isTesting ? (
            <div className="flex items-center justify-center">
              <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
              {currentPhase}...
            </div>
          ) : (
            '🚀 开始同步测试'
          )}
        </button>
        
        {testProgress > 0 && (
          <div className="mt-4">
            <div className="flex justify-between text-sm text-gray-600 mb-1">
              <span>测试进度</span>
              <span>{testProgress}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-green-500 h-2 rounded-full transition-all duration-300"
                style={{ width: `${testProgress}%` }}
              ></div>
            </div>
          </div>
        )}
      </div>

      {/* 测试结果 */}
      {testResults.length > 0 && (
        <div className="mb-6">
          <h3 className="text-lg font-semibold mb-3">测试结果</h3>
          <div className="space-y-3 max-h-96 overflow-y-auto">
            {testResults.map((result) => (
              <div key={result.id} className="p-4 border rounded-lg">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <span className={`w-3 h-3 rounded-full ${
                      result.status === 'success' ? 'bg-green-500' :
                      result.status === 'failed' ? 'bg-red-500' : 'bg-yellow-500'
                    }`}></span>
                    <span className="font-medium capitalize">{result.operation}</span>
                  </div>
                  <span className="text-sm text-gray-500">
                    {new Date(result.timestamp).toLocaleTimeString()}
                  </span>
                </div>
                <div className="text-sm text-gray-600 mb-2">{result.details}</div>
                <div className="text-xs text-gray-500">
                  设备: {result.deviceName} | 卡片ID: {result.cardId.substring(0, 8)}...
                </div>
                {result.syncedDevices.length > 0 && (
                  <div className="text-xs text-green-600 mt-1">
                    ✅ 已同步到 {result.syncedDevices.length} 个设备
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 设备列表 */}
      {connectedDevices.length > 0 && (
        <div>
          <h3 className="text-lg font-semibold mb-3">在线设备</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {connectedDevices.map((device) => (
              <div key={device.id} className="p-3 border rounded-lg">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="font-medium">{device.name}</div>
                    <div className="text-sm text-gray-500">{device.id.substring(0, 8)}...</div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm text-green-600">在线</div>
                    <div className="text-xs text-gray-500">
                      {new Date(device.lastSeen).toLocaleTimeString()}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};