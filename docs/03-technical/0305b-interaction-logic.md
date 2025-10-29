# CardMind UI交互逻辑文档

## 1. 概述

本文档详细描述CardMind应用的UI交互逻辑实现，包括组件状态管理、事件处理、用户操作流程等技术实现细节。本文档与组件定义文档配合使用，为开发团队提供具体的交互实现指南。

## 2. 组件交互逻辑

### 2.1 卡片列表组件 (CardList)

```typescript
const CardList: React.FC = () => {
  // 状态管理
  const [state, setState] = useState<CardListState>({
    cards: [],
    loading: true,
    error: null,
    refreshing: false,
    searchQuery: '',
    filterOptions: {
      showDeleted: false,
      sortBy: 'updatedAt',
      sortOrder: 'desc'
    }
  });
  
  // 从store获取卡片数据
  const { fetchAllCards, fetchDeletedCards } = useCardStore();
  
  // 初始加载
  useEffect(() => {
    loadCards();
  }, [state.filterOptions.showDeleted]);
  
  // 加载卡片数据
  const loadCards = async () => {
    setState(prev => ({ ...prev, loading: true, error: null }));
    try {
      const cards = state.filterOptions.showDeleted 
        ? await fetchDeletedCards() 
        : await fetchAllCards();
      setState(prev => ({ ...prev, cards, loading: false }));
    } catch (err) {
      setState(prev => ({ 
        ...prev, 
        error: '加载卡片失败，请重试', 
        loading: false 
      }));
    }
  };
  
  // 下拉刷新
  const handleRefresh = async () => {
    setState(prev => ({ ...prev, refreshing: true }));
    await loadCards();
    setState(prev => ({ ...prev, refreshing: false }));
  };
  
  // 搜索过滤
  const handleSearch = (query: string) => {
    setState(prev => ({ ...prev, searchQuery: query }));
  };
  
  // 过滤和排序卡片
  const filteredAndSortedCards = useMemo(() => {
    let filtered = [...state.cards];
    
    // 搜索过滤
    if (state.searchQuery) {
      const query = state.searchQuery.toLowerCase();
      filtered = filtered.filter(card => 
        card.title.toLowerCase().includes(query) ||
        card.content.toLowerCase().includes(query)
      );
    }
    
    // 排序
    filtered.sort((a, b) => {
      const aValue = a[state.filterOptions.sortBy];
      const bValue = b[state.filterOptions.sortBy];
      
      if (state.filterOptions.sortOrder === 'asc') {
        return aValue - bValue;
      } else {
        return bValue - aValue;
      }
    });
    
    return filtered;
  }, [state.cards, state.searchQuery, state.filterOptions]);
  
  // 渲染卡片项
  const renderCardItem = (card: Card) => {
    return (
      <CardItem 
        key={card.id}
        card={card}
        onView={() => handleViewCard(card)}
        onEdit={() => handleEditCard(card)}
        onDelete={() => handleDeleteCard(card)}
        onRestore={state.filterOptions.showDeleted ? () => handleRestoreCard(card) : undefined}
      />
    );
  };
  
  return (
    <div className="card-list-container">
      {/* 搜索栏 */}
      <SearchBar 
        value={state.searchQuery}
        onChange={handleSearch}
        placeholder="搜索卡片..."
      />
      
      {/* 过滤选项 */}
      <FilterOptions 
        options={state.filterOptions}
        onChange={(options) => setState(prev => ({ ...prev, filterOptions: options }))}
      />
      
      {/* 卡片列表 */}
      {state.loading && !state.refreshing ? (
        <LoadingSpinner />
      ) : state.error ? (
        <ErrorMessage message={state.error} onRetry={loadCards} />
      ) : filteredAndSortedCards.length === 0 ? (
        <EmptyState 
          message={state.filterOptions.showDeleted ? "没有已删除的卡片" : "没有卡片，点击下方按钮创建"}
        />
      ) : (
        <RefreshControl
          refreshing={state.refreshing}
          onRefresh={handleRefresh}
          children={
            filteredAndSortedCards.map(renderCardItem)
          }
        />
      )}
      
      {/* 添加按钮 */}
      {!state.filterOptions.showDeleted && (
        <FloatingActionButton onClick={handleAddCard} icon="+" />
      )}
    </div>
  );
};
```

### 2.2 卡片编辑器组件 (CardEditor)

```typescript
const CardEditor: React.FC<CardEditorProps> = ({ initialCard, onClose, onSaveSuccess }) => {
  // 初始化状态
  const [state, setState] = useState<CardEditorState>({
    id: initialCard?.id || null,
    title: initialCard?.title || '',
    content: initialCard?.content || '',
    saving: false,
    error: null,
    isNewCard: !initialCard,
    maxTitleLength: 100,
    maxContentLength: 5000
  });
  
  // 使用CardService
  const { createCard, updateCard } = useCardStore();
  
  // 验证输入
  const isValid = state.title.trim().length > 0 && 
                 state.content.trim().length > 0 &&
                 state.title.length <= state.maxTitleLength &&
                 state.content.length <= state.maxContentLength;
  
  // 处理标题变化
  const handleTitleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const title = e.target.value;
    if (title.length <= state.maxTitleLength) {
      setState(prev => ({ ...prev, title, error: null }));
    }
  };
  
  // 处理内容变化
  const handleContentChange = (content: string) => {
    if (content.length <= state.maxContentLength) {
      setState(prev => ({ ...prev, content, error: null }));
    }
  };
  
  // 保存卡片
  const handleSave = async () => {
    if (!isValid) {
      setState(prev => ({
        ...prev,
        error: '请填写有效的标题和内容，且不超过字数限制'
      }));
      return;
    }
    
    setState(prev => ({ ...prev, saving: true, error: null }));
    
    try {
      let savedCard;
      
      if (state.isNewCard) {
        // 创建新卡片
        savedCard = await createCard({
          title: state.title.trim(),
          content: state.content.trim()
        });
      } else {
        // 更新现有卡片
        if (!state.id) throw new Error('卡片ID不存在');
        savedCard = await updateCard(state.id, {
          title: state.title.trim(),
          content: state.content.trim()
        });
      }
      
      // 保存成功回调
      onSaveSuccess(savedCard);
      onClose();
    } catch (err) {
      setState(prev => ({
        ...prev,
        error: state.isNewCard ? '创建卡片失败' : '更新卡片失败',
        saving: false
      }));
    }
  };
  
  // 处理取消
  const handleCancel = () => {
    if (state.title.trim() || state.content.trim()) {
      // 如果有未保存的内容，显示确认对话框
      showConfirmDialog({
        title: '确认离开',
        message: '有未保存的内容，确定要离开吗？',
        onConfirm: onClose
      });
    } else {
      onClose();
    }
  };
  
  return (
    <ModalDialog
      open={true}
      title={state.isNewCard ? '创建新卡片' : '编辑卡片'}
      onClose={handleCancel}
      footer={
        <>
          <Button onClick={handleCancel} disabled={state.saving}>
            取消
          </Button>
          <Button 
            primary 
            onClick={handleSave} 
            disabled={!isValid || state.saving}
            loading={state.saving}
          >
            保存
          </Button>
        </>
      }
    >
      {/* 错误提示 */}
      {state.error && <ErrorMessage message={state.error} />}
      
      {/* 标题输入 */}
      <InputField
        label="标题"
        value={state.title}
        onChange={handleTitleChange}
        placeholder="输入卡片标题"
        maxLength={state.maxTitleLength}
      />
      <TextCounter 
        current={state.title.length} 
        max={state.maxTitleLength}
        warningThreshold={0.9}
      />
      
      {/* 内容编辑器 */}
      <RichTextEditor
        value={state.content}
        onChange={handleContentChange}
        placeholder="输入卡片内容"
      />
      <TextCounter 
        current={state.content.length} 
        max={state.maxContentLength}
        warningThreshold={0.9}
      />
    </ModalDialog>
  );
};
```

### 2.3 网络认证组件 (NetworkAuth)

```typescript
const NetworkAuth: React.FC<NetworkAuthProps> = ({ onSuccess }) => {
  const [state, setState] = useState<NetworkAuthState>({
    accessCode: '',
    isGenerating: false,
    isJoining: false,
    error: null,
    showAdvanced: false,
    autoJoinMode: false
  });
  
  // 使用AuthService
  const { joinNetwork, generateNetworkId, generateAccessCode, validateAccessCode } = useAuthStore();
  
  // Access Code只在需要时生成，不保存到本地存储
  
  // 处理Access Code输入变化
  const handleAccessCodeChange = (value: string) => {
    setState(prev => ({ ...prev, accessCode: value, error: '' }));
  };
  
  // 生成新网络
  const handleGenerateNetwork = async () => {
    setState(prev => ({ ...prev, isGenerating: true, error: null }));
    
    try {
      const newNetworkId = await generateNetworkId();
      const accessCode = await generateAccessCode(newNetworkId);
      
      // 保存网络ID到本地存储
      localStorage.setItem('currentNetworkId', newNetworkId);
      
      setState(prev => ({ 
        ...prev, 
        accessCode: accessCode, 
        isGenerating: false,
        autoJoinMode: true
      }));
      
      showToast('新网络生成成功！');
    } catch (err) {
      setState(prev => ({
        ...prev,
        error: '生成网络失败',
        isGenerating: false
      }));
    }
  };
  
  // 加入网络
  const handleJoinNetwork = async () => {
    if (!state.accessCode) {
      setState(prev => ({ ...prev, error: '请输入Access Code' }));
      return;
    }
    
    if (!validateAccessCode(state.accessCode)) {
      setState(prev => ({ ...prev, error: 'Access Code格式不正确' }));
      return;
    }
    
    try {
      setState(prev => ({ ...prev, isJoining: true, error: null }));
      
      await joinNetwork(state.accessCode);
      
      showToast('成功加入网络！');
      
      // 跳转到主界面
      router.push('/cards');
    } catch (error) {
      setState(prev => ({ 
        ...prev, 
        isJoining: false, 
        error: '加入网络失败，请检查Access Code是否正确' 
      }));
    }
  };
  
  // 跳过网络认证
  const handleSkip = () => {
    showConfirmDialog({
      title: '跳过网络认证',
      message: '跳过网络认证将无法与其他设备同步数据。确定要跳过吗？',
      onConfirm: onSuccess
    });
  };
  
  // 复制当前Access Code
  const handleCopyAccessCode = async () => {
    if (state.accessCode && validateAccessCode(state.accessCode)) {
      try {
        await navigator.clipboard.writeText(state.accessCode);
        showToast('Access Code已复制到剪贴板');
      } catch (err) {
        showToast('复制失败，请手动复制');
      }
    }
  };
  
  return (
    <div className="network-auth-container">
      <h1>欢迎使用 CardMind</h1>
      <p>请输入Access Code加入现有网络，或生成新的Access Code</p>
      
      {/* 错误提示 */}
      {state.error && <ErrorMessage message={state.error} />}
      
      {/* Access Code输入区域 */}
      <InputWithButton
        value={state.accessCode}
        onChange={handleAccessCodeChange}
        placeholder="输入Access Code"
        buttonLabel="复制"
        onButtonClick={handleCopyAccessCode}
        disabled={!state.accessCode || state.isJoining || state.isGenerating}
      />
      
      {/* 操作按钮 */}
      <ButtonGroup>
        <Button
          onClick={handleJoinNetwork}
          disabled={!state.accessCode || state.isJoining || state.isGenerating}
          loading={state.isJoining}
        >
          加入网络
        </Button>
        
        <Button
          onClick={handleGenerateNetwork}
          disabled={state.isJoining || state.isGenerating}
          loading={state.isGenerating}
        >
          生成新网络
        </Button>
      </ButtonGroup>
      
      {/* 跳过选项 */}
      <ButtonLink onClick={handleSkip} variant="text">
        跳过网络设置
      </ButtonLink>
      
      {/* 自动加入模式提示 */}
      {state.autoJoinMode && (
        <InfoBanner message="已自动生成并复制Access Code，请分享给需要同步的设备" />
      )}
      
      {/* 高级选项 */}
      <AdvancedOptions 
        show={state.showAdvanced}
        onToggle={() => setState(prev => ({ ...prev, showAdvanced: !prev.showAdvanced }))}
      />
    </div>
  );
};
```

## 3. 页面导航与路由逻辑

### 3.1 路由配置
```typescript
// 主路由配置
const AppRouter: React.FC = () => {
  const { isAuthenticated } = useAuthStore();
  const [isLoading, setIsLoading] = useState(true);
  
  // 应用初始化
  useEffect(() => {
    const initializeApp = async () => {
      try {
        // 初始化设备信息
        await useDeviceStore.getState().initializeDevice();
        
        // 检查是否已认证
        const savedNetworkId = localStorage.getItem('currentNetworkId');
        if (savedNetworkId) {
          try {
            await useAuthStore.getState().joinNetwork(savedNetworkId);
          } catch (error) {
            // 加入失败，清除保存的网络ID
            localStorage.removeItem('currentNetworkId');
          }
        }
      } finally {
        setIsLoading(false);
      }
    };
    
    initializeApp();
  }, []);
  
  if (isLoading) {
    return <AppLoadingScreen />;
  }
  
  return (
    <Router>
      <Routes>
        {/* 无需认证的路由 */}
        <Route path="/auth" element={<NetworkAuthScreen />} />
        <Route path="/onboarding" element={<OnboardingScreen />} />
        
        {/* 需要认证的路由 */}
        <Route 
          path="/" 
          element={
            <ProtectedRoute isAuthenticated={isAuthenticated}>
              <MainScreen />
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/settings" 
          element={
            <ProtectedRoute isAuthenticated={isAuthenticated}>
              <SettingsScreen />
            </ProtectedRoute>
          } 
        />
        
        {/* 全局404页面 */}
        <Route path="*" element={<NotFoundScreen />} />
      </Routes>
    </Router>
  );
};

// 受保护的路由组件
const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ isAuthenticated, children }) => {
  if (!isAuthenticated) {
    // 未认证状态下重定向到认证页面
    return <Navigate to="/auth" replace />;
  }
  
  return <>{children}</>;
};
```

### 3.2 页面导航逻辑
```typescript
// 导航服务实现
class NavigationService {
  // 导航到主页
  navigateToHome(): void {
    window.location.hash = '#/';
  }
  
  // 导航到认证页面
  navigateToAuth(): void {
    window.location.hash = '#/auth';
  }
  
  // 导航到设置页面
  navigateToSettings(): void {
    window.location.hash = '#/settings';
  }
  
  // 导航到引导页
  navigateToOnboarding(): void {
    window.location.hash = '#/onboarding';
  }
  
  // 重新加载当前页面
  reload(): void {
    window.location.reload();
  }
  
  // 返回上一页
  goBack(): void {
    window.history.back();
  }
  
  // 清除导航历史并跳转
  redirectTo(url: string): void {
    window.location.replace(url);
  }
  
  // 打开外部链接
  openExternalLink(url: string, target?: '_blank' | '_self' | '_parent' | '_top'): void {
    window.open(url, target || '_blank');
  }
}

// 使用示例
const navigationService = new NavigationService();
```

## 4. 模态框与对话框管理

### 4.1 模态框管理器实现
```typescript
// 模态框提供者组件
const ModalProvider: React.FC<ModalProviderProps> = ({ children }) => {
  const [currentModal, setCurrentModal] = useState<{ type: ModalType | null; props: any }>({
    type: null,
    props: {}
  });
  
  // 打开模态框
  const openModal = (modalType: ModalType, props: any = {}) => {
    setCurrentModal({ type: modalType, props });
  };
  
  // 关闭模态框
  const closeModal = () => {
    setCurrentModal({ type: null, props: {} });
  };
  
  // 渲染模态框
  const renderModal = () => {
    if (!currentModal.type) return null;
    
    const { type, props } = currentModal;
    
    switch (type) {
      case 'cardEdit':
        return <CardEditModal {...props} onClose={closeModal} />;
      case 'cardView':
        return <CardViewModal {...props} onClose={closeModal} />;
      case 'confirm':
        return <ConfirmDialog {...props} onClose={closeModal} />;
      case 'settings':
          return <SettingsModal {...props} onClose={closeModal} />;
        case 'networkSetup':
          return <AccessCodeSetupModal {...props} onClose={closeModal} />;
        default:
        return null;
    }
  };
  
  const value = {
    openModal,
    closeModal,
    currentModal
  };
  
  return (
    <ModalContext.Provider value={value}>
      {children}
      {renderModal()}
    </ModalContext.Provider>
  );
};

// 模态框钩子
const useModal = () => {
  const context = useContext(ModalContext);
  if (!context) {
    throw new Error('useModal must be used within a ModalProvider');
  }
  return context;
};
```

### 4.2 对话框工具函数实现
```typescript
// 显示确认对话框
export const showConfirmDialog = (options: ConfirmDialogOptions): void => {
  const { openModal } = useModal.getState();
  
  openModal('confirm', {
    ...options,
    confirmText: options.confirmText || '确认',
    cancelText: options.cancelText || '取消',
    confirmVariant: options.confirmVariant || 'primary'
  });
};

// 显示消息提示
export const showToast = (message: string, options?: Partial<ToastOptions>): void => {
  const toastId = `toast-${Date.now()}`;
  
  // 实现Toast逻辑...
  // 这里可以集成第三方Toast库或自定义实现
};
```

## 5. 事件总线与跨组件通信

### 5.1 事件总线实现
```typescript
// 事件总线类
class EventBus {
  private events: Map<EventType, Set<EventCallback>> = new Map();
  
  // 订阅事件
  on<T = any>(event: EventType, callback: EventCallback<T>): () => void {
    if (!this.events.has(event)) {
      this.events.set(event, new Set());
    }
    
    this.events.get(event)?.add(callback);
    
    // 返回取消订阅函数
    return () => {
      this.off(event, callback);
    };
  }
  
  // 取消订阅
  off<T = any>(event: EventType, callback: EventCallback<T>): void {
    this.events.get(event)?.delete(callback);
    
    // 如果事件没有监听器了，移除该事件
    if (this.events.get(event)?.size === 0) {
      this.events.delete(event);
    }
  }
  
  // 触发事件
  emit<T = any>(event: EventType, data?: T): void {
    this.events.get(event)?.forEach(callback => {
      try {
        callback(data);
      } catch (error) {
        console.error(`Error in event handler for ${event}:`, error);
      }
    });
  }
  
  // 订阅一次事件
  once<T = any>(event: EventType, callback: EventCallback<T>): () => void {
    const onceCallback: EventCallback<T> = (data) => {
      this.off(event, onceCallback);
      callback(data);
    };
    
    return this.on(event, onceCallback);
  }
  
  // 清除所有事件监听器
  clear(): void {
    this.events.clear();
  }
  
  // 获取事件监听器数量
  getListenersCount(event?: EventType): number {
    if (event) {
      return this.events.get(event)?.size || 0;
    }
    
    let count = 0;
    this.events.forEach(set => {
      count += set.size;
    });
    
    return count;
  }
}

// 导出事件总线实例
export const eventBus = new EventBus();
```

### 5.2 跨组件通信示例
```typescript
// 在卡片列表组件中监听卡片更新事件
const CardList: React.FC = () => {
  const [cards, setCards] = useState<Card[]>([]);
  
  useEffect(() => {
    // 加载卡片数据
    const loadCards = async () => {
      const cardService = new CardService();
      const data = await cardService.getAllCards();
      setCards(data);
    };
    
    loadCards();
    
    // 监听卡片创建、更新、删除事件
    const unsubscribeCreated = eventBus.on<Card>('card:created', (newCard) => {
      setCards(prev => [...prev, newCard]);
    });
    
    const unsubscribeUpdated = eventBus.on<Card>('card:updated', (updatedCard) => {
      setCards(prev => 
        prev.map(card => 
          card.id === updatedCard.id ? updatedCard : card
        )
      );
    });
    
    const unsubscribeDeleted = eventBus.on<string>('card:deleted', (cardId) => {
      setCards(prev => prev.filter(card => card.id !== cardId));
    });
    
    // 清理订阅
    return () => {
      unsubscribeCreated();
      unsubscribeUpdated();
      unsubscribeDeleted();
    };
  }, []);
  
  // 渲染组件...
};

// 在卡片编辑器组件中触发事件
const CardEditor: React.FC = () => {
  const handleSave = async () => {
    // 保存卡片逻辑
    const savedCard = await cardService.createCard({ title, content });
    
    // 触发卡片创建事件
    eventBus.emit('card:created', savedCard);
    
    // 显示成功提示
    showToast('卡片创建成功', { type: 'success' });
  };
  
  // 渲染组件...
};
```

## 6. 响应式设计与设备适配

### 6.1 响应式Hook实现
```typescript
// React Hook for responsive design
export const useResponsive = () => {
  const [deviceType, setDeviceType] = useState<'mobile' | 'tablet' | 'desktop'>(
    ResponsiveUtils.getDeviceType()
  );
  
  useEffect(() => {
    const unsubscribe = ResponsiveUtils.onResize(setDeviceType);
    return unsubscribe;
  }, []);
  
  return {
    deviceType,
    isMobile: deviceType === 'mobile',
    isTablet: deviceType === 'tablet',
    isDesktop: deviceType === 'desktop'
  };
};
```

### 6.2 响应式组件实现
```typescript
// 响应式布局组件
const ResponsiveLayout: React.FC<ResponsiveLayoutProps> = ({ children }) => {
  const { deviceType, isMobile, isTablet, isDesktop } = useResponsive();
  
  return (
    <div className={`layout-container layout-${deviceType}`}>
      {/* 头部导航 */}
      <Header 
        showSearch={isDesktop} 
        compact={isMobile}
      />
      
      {/* 主内容区 */}
      <main className="main-content">
        {children}
      </main>
      
      {/* 底部导航 - 仅在移动端显示 */}
      {isMobile && <BottomNavigation />}
      
      {/* 侧边栏 - 仅在桌面端显示，或在平板端通过抽屉式显示 */}
      {isDesktop ? (
        <Sidebar />
      ) : isTablet ? (
        <DrawerSidebar />
      ) : null}
    </div>
  );
};

// 响应式卡片网格
const ResponsiveCardGrid: React.FC<ResponsiveCardGridProps> = ({ 
  cards, 
  onCardClick 
}) => {
  const { deviceType } = useResponsive();
  
  // 根据设备类型计算列数
  const getColumnsCount = () => {
    switch (deviceType) {
      case 'mobile':
        return 1;
      case 'tablet':
        return 2;
      case 'desktop':
        return 3;
      default:
        return 1;
    }
  };
  
  const columnsCount = getColumnsCount();
  
  return (
    <div className={`card-grid columns-${columnsCount}`}>
      {cards.map(card => (
        <CardItem 
          key={card.id}
          card={card}
          onClick={() => onCardClick(card)}
          compact={deviceType === 'mobile'}
        />
      ))}
    </div>
  );
};
```

## 7. 键盘快捷键与辅助功能

### 7.1 快捷键管理器实现
```typescript
// 快捷键管理器
class ShortcutManager {
  private shortcuts: Map<string, Shortcut> = new Map();
  private isListening: boolean = false;
  
  // 注册快捷键
  register(shortcut: Shortcut): void {
    const key = this.getKeyString(shortcut);
    this.shortcuts.set(key, shortcut);
  }
  
  // 注销快捷键
  unregister(shortcut: Shortcut): void {
    const key = this.getKeyString(shortcut);
    this.shortcuts.delete(key);
  }
  
  // 生成快捷键唯一标识
  private getKeyString(shortcut: Shortcut): string {
    return `${shortcut.ctrlKey ? 'ctrl+' : ''}${shortcut.altKey ? 'alt+' : ''}${shortcut.shiftKey ? 'shift+' : ''}${shortcut.metaKey ? 'meta+' : ''}${shortcut.key.toLowerCase()}`;
  }
  
  // 开始监听键盘事件
  startListening(): void {
    if (!this.isListening) {
      document.addEventListener('keydown', this.handleKeyDown);
      this.isListening = true;
    }
  }
  
  // 停止监听键盘事件
  stopListening(): void {
    if (this.isListening) {
      document.removeEventListener('keydown', this.handleKeyDown);
      this.isListening = false;
    }
  }
  
  // 处理键盘事件
  private handleKeyDown = (event: KeyboardEvent): void => {
    // 忽略在输入框或编辑器中的快捷键
    if (['INPUT', 'TEXTAREA', 'SELECT', 'CONTENTEDITABLE'].some(tag => 
      (event.target as HTMLElement).matches(tag) || 
      (event.target as HTMLElement).isContentEditable
    )) {
      return;
    }
    
    // 查找匹配的快捷键
    for (const [key, shortcut] of this.shortcuts.entries()) {
      if (
        shortcut.key.toLowerCase() === event.key.toLowerCase() &&
        shortcut.altKey === event.altKey &&
        shortcut.ctrlKey === (event.ctrlKey || event.metaKey) && // 处理 Cmd/Ctrl 兼容性
        shortcut.metaKey === event.metaKey &&
        shortcut.shiftKey === event.shiftKey
      ) {
        event.preventDefault();
        event.stopPropagation();
        shortcut.action();
        break;
      }
    }
  };
  
  // 获取所有注册的快捷键
  getAllShortcuts(): Shortcut[] {
    return Array.from(this.shortcuts.values());
  }
  
  // 清除所有快捷键
  clear(): void {
    this.shortcuts.clear();
  }
}

// 创建全局快捷键管理器实例
const shortcutManager = new ShortcutManager();

// 初始化应用快捷键
export const initializeShortcuts = (): void => {
  // 开始监听
  shortcutManager.startListening();
  
  // 注册全局快捷键
  shortcutManager.register({
    key: 'n',
    ctrlKey: true,
    description: '新建卡片',
    action: () => {
      const { openModal } = useModal.getState();
      openModal('cardEdit', { isNew: true });
    }
  });
  
  shortcutManager.register({
    key: 'f',
    ctrlKey: true,
    description: '搜索',
    action: () => {
      const searchInput = document.getElementById('global-search');
      if (searchInput) {
        searchInput.focus();
      }
    }
  });
  
  shortcutManager.register({
    key: 'Escape',
    description: '关闭当前模态框',
    action: () => {
      const { closeModal } = useModal.getState();
      closeModal();
    }
  });
};

// React Hook for shortcut management
export const useShortcuts = () => {
  useEffect(() => {
    const registerShortcut = (shortcut: Shortcut) => {
      shortcutManager.register(shortcut);
      return () => shortcutManager.unregister(shortcut);
    };
    
    return {
      registerShortcut,
      getAllShortcuts: shortcutManager.getAllShortcuts
    };
  }, []);
};
```

### 7.2 辅助功能Hook实现
```typescript
// React Hook for accessibility
export const useAccessibility = () => {
  const [highContrastMode, setHighContrastMode] = useState(
    AccessibilityUtils.isHighContrastMode()
  );
  
  const [reducedMotionMode, setReducedMotionMode] = useState(
    AccessibilityUtils.isReducedMotionMode()
  );
  
  useEffect(() => {
    // 监听高对比度模式变化
    const highContrastQuery = window.matchMedia('(prefers-contrast: high), (contrast: high)');
    const handleHighContrastChange = (e: MediaQueryListEvent) => {
      setHighContrastMode(e.matches);
    };
    
    highContrastQuery.addEventListener('change', handleHighContrastChange);
    
    // 监听减少动画模式变化
    const reducedMotionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    const handleReducedMotionChange = (e: MediaQueryListEvent) => {
      setReducedMotionMode(e.matches);
    };
    
    reducedMotionQuery.addEventListener('change', handleReducedMotionChange);
    
    return () => {
      highContrastQuery.removeEventListener('change', handleHighContrastChange);
      reducedMotionQuery.removeEventListener('change', handleReducedMotionChange);
    };
  }, []);
  
  return {
    highContrastMode,
    reducedMotionMode,
    announce: AccessibilityUtils.announce,
    focusElement: AccessibilityUtils.focusElement,
    makeAccessible: AccessibilityUtils.makeAccessible
  };
};
```

## 8. 性能优化策略

### 8.1 组件懒加载实现
```typescript
// 路由级别的懒加载
const CardListScreen = React.lazy(() => import('../screens/CardListScreen'));
const SettingsScreen = React.lazy(() => import('../screens/SettingsScreen'));
const NetworkAuthScreen = React.lazy(() => import('../screens/NetworkAuthScreen'));

// 路由配置
const AppRouter: React.FC = () => {
  return (
    <Router>
      <React.Suspense fallback={<AppLoadingScreen />}>
        <Routes>
          <Route path="/" element={<CardListScreen />} />
          <Route path="/settings" element={<SettingsScreen />} />
          <Route path="/auth" element={<NetworkAuthScreen />} />
        </Routes>
      </React.Suspense>
    </Router>
  );
};

// 组件级别的懒加载钩子
const useLazyComponent = <T extends React.ComponentType<any>>(importFn: () => Promise<{ default: T }>) => {
  const [Component, setComponent] = useState<T | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  
  const loadComponent = useCallback(async () => {
    if (Component) return Component;
    
    setLoading(true);
    setError(null);
    
    try {
      const module = await importFn();
      setComponent(module.default);
      return module.default;
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Failed to load component'));
      throw err;
    } finally {
      setLoading(false);
    }
  }, [Component, importFn]);
  
  return { Component, loading, error, loadComponent };
};

// 使用示例
const HeavyEditorSection: React.FC = () => {
  const { Component: RichTextEditor, loading } = useLazyComponent(() => 
    import('@/components/RichTextEditor')
  );
  
  if (loading) {
    return <EditorSkeleton />;
  }
  
  if (!Component) {
    return <ErrorMessage message="编辑器加载失败" />;
  }
  
  return <Component />;
};
```

### 8.2 虚拟列表实现
```typescript
// 虚拟列表组件
const VirtualList = <T,>({ 
  items, 
  itemHeight, 
  containerHeight, 
  renderItem, 
  keyExtractor, 
  overscanCount = 5,
  onScroll
}: VirtualListProps<T>) => {
  const [scrollTop, setScrollTop] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);
  
  // 计算总高度
  const totalHeight = items.length * itemHeight;
  
  // 计算可见项范围
  const startIndex = Math.floor(scrollTop / itemHeight);
  const endIndex = Math.min(
    startIndex + Math.ceil(containerHeight / itemHeight) + overscanCount,
    items.length
  );
  
  // 确保开始索引不会小于0
  const safeStartIndex = Math.max(0, startIndex - overscanCount);
  
  // 计算偏移量
  const offsetY = safeStartIndex * itemHeight;
  
  // 获取可见项
  const visibleItems = items.slice(safeStartIndex, endIndex);
  
  // 处理滚动
  const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const newScrollTop = e.currentTarget.scrollTop;
    setScrollTop(newScrollTop);
    onScroll?.(newScrollTop);
  };
  
  return (
    <div 
      ref={containerRef}
      className="virtual-list-container"
      style={{ 
        height: containerHeight,
        overflow: 'auto',
        position: 'relative'
      }}
      onScroll={handleScroll}
    >
      {/* 占位元素，保持滚动条高度 */}
      <div style={{ height: totalHeight }} />
      
      {/* 可见项容器 */}
      <div 
        className="virtual-list-items"
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          transform: `translateY(${offsetY}px)`
        }}
      >
        {visibleItems.map((item, index) => {
          const actualIndex = safeStartIndex + index;
          return (
            <div
              key={keyExtractor(item)}
              style={{ height: itemHeight }}
            >
              {renderItem(item, actualIndex)}
            </div>
          );
        })}
      </div>
    </div>
  );
};

// 使用示例
const CardVirtualList: React.FC = () => {
  const { cards } = useCardStore();
  const { deviceType } = useResponsive();
  
  // 根据设备类型调整容器高度
  const containerHeight = deviceType === 'mobile' ? window.innerHeight - 200 : 600;
  
  // 卡片项高度
  const cardItemHeight = 120;
  
  return (
    <VirtualList
      items={cards}
      itemHeight={cardItemHeight}
      containerHeight={containerHeight}
      renderItem={(card) => (
        <CardItem 
          card={card}
          onView={() => handleViewCard(card)}
          onEdit={() => handleEditCard(card)}
        />
      )}
      keyExtractor={(card) => card.id}
      overscanCount={3}
    />
  );
};
```

### 8.3 防抖与节流实现
```typescript
// 防抖函数
function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout | null = null;
  
  return function(...args: Parameters<T>) {
    if (timeout) {
      clearTimeout(timeout);
    }
    
    timeout = setTimeout(() => {
      func.apply(this, args);
      timeout = null;
    }, wait);
  };
}

// 节流函数
function throttle<T extends (...args: any[]) => any>(
  func: T,
  limit: number
): (...args: Parameters<T>) => void {
  let inThrottle: boolean = false;
  
  return function(...args: Parameters<T>) {
    if (!inThrottle) {
      func.apply(this, args);
      inThrottle = true;
      
      setTimeout(() => {
        inThrottle = false;
      }, limit);
    }
  };
}

// React Hook for debounce
function useDebounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  const funcRef = useRef<T>(func);
  
  // 更新func引用，确保使用最新的函数
  useEffect(() => {
    funcRef.current = func;
  }, [func]);
  
  // 使用useMemo避免每次渲染都创建新的debounce函数
  return useMemo(() => {
    return debounce((...args: Parameters<T>) => {
      funcRef.current.apply(this, args);
    }, wait);
  }, [wait]);
}

// 使用示例
const SearchComponent: React.FC = () => {
  const [searchQuery, setSearchQuery] = useState('');
  const [results, setResults] = useState<any[]>([]);
  
  // 防抖的搜索函数
  const debouncedSearch = useDebounce(async (query: string) => {
    if (!query.trim()) {
      setResults([]);
      return;
    }
    
    try {
      const searchResults = await searchService.search(query);
      setResults(searchResults);
    } catch (error) {
      console.error('搜索失败:', error);
    }
  }, 300);
  
  // 处理搜索输入变化
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setSearchQuery(value);
    debouncedSearch(value);
  };
  
  return (
    <div className="search-component">
      <Input
        value={searchQuery}
        onChange={handleSearchChange}
        placeholder="搜索..."
      />
      
      {results.length > 0 && (
        <SearchResults results={results} />
      )}
    </div>
  );
};
```

## 9. 动画与过渡效果

### 9.1 动画Hook实现
```typescript
// React Hook for animations
function useAnimation() {
  const { reducedMotionMode } = useAccessibility();
  
  const animateElement = useCallback(async (
    element: HTMLElement,
    keyframes: Keyframe[] | PropertyIndexedKeyframes,
    config?: AnimationConfig
  ) => {
    // 如果用户设置了减少动画，则跳过动画
    if (reducedMotionMode) {
      return Promise.resolve();
    }
    
    return AnimationUtils.animateElement(element, keyframes, config);
  }, [reducedMotionMode]);
  
  return {
    animateElement,
    fadeIn: useCallback((element: HTMLElement, config?: AnimationConfig) => {
      if (reducedMotionMode) return Promise.resolve();
      return AnimationUtils.fadeIn(element, config);
    }, [reducedMotionMode]),
    fadeOut: useCallback((element: HTMLElement, config?: AnimationConfig) => {
      if (reducedMotionMode) return Promise.resolve();
      return AnimationUtils.fadeOut(element, config);
    }, [reducedMotionMode]),
    slideIn: useCallback((element: HTMLElement, direction?: 'left' | 'right' | 'top' | 'bottom', config?: AnimationConfig) => {
      if (reducedMotionMode) return Promise.resolve();
      return AnimationUtils.slideIn(element, direction, config);
    }, [reducedMotionMode]),
    bounce: useCallback((element: HTMLElement, config?: AnimationConfig) => {
      if (reducedMotionMode) return Promise.resolve();
      return AnimationUtils.bounce(element, config);
    }, [reducedMotionMode]),
    pulse: useCallback((element: HTMLElement, config?: AnimationConfig) => {
      if (reducedMotionMode) return Promise.resolve();
      return AnimationUtils.pulse(element, config);
    }, [reducedMotionMode]),
    stopAnimation: AnimationUtils.stopAnimation,
    getAnimationState: AnimationUtils.getAnimationState,
    reducedMotionMode
  };
}
```

### 9.2 过渡组件实现
```typescript
// 淡入淡出过渡组件
const FadeTransition: React.FC<FadeTransitionProps> = ({
  in: inProp,
  children,
  timeout = 300,
  unmountOnExit = false,
  onEnter,
  onEntering,
  onEntered,
  onExit,
  onExiting,
  onExited,
  className
}) => {
  const nodeRef = useRef<HTMLDivElement>(null);
  const [status, setStatus] = useState<'exited' | 'entering' | 'entered' | 'exiting'>(
    inProp ? 'entered' : 'exited'
  );
  const { reducedMotionMode } = useAccessibility();
  
  useEffect(() => {
    if (inProp) {
      enter();
    } else {
      exit();
    }
  }, [inProp]);
  
  const enter = async () => {
    if (status === 'entered' || status === 'entering') return;
    
    setStatus('entering');
    
    if (nodeRef.current) {
      onEnter?.(nodeRef.current);
      
      // 设置初始状态
      nodeRef.current.style.opacity = '0';
      nodeRef.current.style.transition = `opacity ${timeout}ms ease-in-out`;
      
      // 强制重绘
      nodeRef.current.offsetHeight;
      
      onEntering?.(nodeRef.current);
      
      // 如果启用了减少动画模式，直接设置最终状态
      if (reducedMotionMode) {
        nodeRef.current.style.opacity = '1';
        setStatus('entered');
        onEntered?.(nodeRef.current);
        return;
      }
      
      // 应用最终状态
      nodeRef.current.style.opacity = '1';
      
      // 等待过渡完成
      setTimeout(() => {
        if (nodeRef.current) {
          setStatus('entered');
          onEntered?.(nodeRef.current);
        }
      }, timeout);
    }
  };
  
  const exit = async () => {
    if (status === 'exited' || status === 'exiting') return;
    
    setStatus('exiting');
    
    if (nodeRef.current) {
      onExit?.(nodeRef.current);
      
      // 设置过渡样式
      nodeRef.current.style.transition = `opacity ${timeout}ms ease-in-out`;
      
      onExiting?.(nodeRef.current);
      
      // 应用最终状态
      nodeRef.current.style.opacity = '0';
      
      // 如果启用了减少动画模式，直接设置最终状态
      if (reducedMotionMode) {
        setStatus('exited');
        onExited?.(nodeRef.current);
        return;
      }
      
      // 等待过渡完成
      setTimeout(() => {
        if (nodeRef.current) {
          setStatus('exited');
          onExited?.(nodeRef.current);
        }
      }, timeout);
    }
  };
  
  // 如果未进入且设置了unmountOnExit，则不渲染
  if (!inProp && status === 'exited' && unmountOnExit) {
    return null;
  }
  
  return (
    <div
      ref={nodeRef}
      className={className}
      style={{
        opacity: status === 'exited' ? 0 : 1,
        pointerEvents: status === 'exiting' || status === 'exited' ? 'none' : 'auto'
      }}
    >
      {children}
    </div>
  );
};

// 滑入过渡组件
const SlideTransition: React.FC<SlideTransitionProps> = ({
  direction = 'left',
  distance = '20px',
  ...fadeProps
}) => {
  const getTransform = (inProp: boolean) => {
    const translations = {
      left: inProp ? '0' : `-${distance}`,
      right: inProp ? '0' : distance,
      up: inProp ? '0' : distance,
      down: inProp ? '0' : `-${distance}`
    };
    
    const axis = direction === 'left' || direction === 'right' ? 'X' : 'Y';
    return `translate${axis}(${translations[direction]})`;
  };

  return (
    <FadeTransition
      {...fadeProps}
      onEnter={(node) => {
        fadeProps.onEnter?.(node);
        node.style.transform = getTransform(false);
      }}
      onEntering={(node) => {
        fadeProps.onEntering?.(node);
        node.style.transform = getTransform(true);
      }}
      onExit={(node) => {
        fadeProps.onExit?.(node);
      }}
      onExiting={(node) => {
        fadeProps.onExiting?.(node);
        node.style.transform = getTransform(false);
      }}
      className={fadeProps.className}
    >
      <div style={{ transition: `transform ${fadeProps.timeout || 300}ms ease-in-out` }}>
        {fadeProps.children}
      </div>
    </FadeTransition>
  );
};
```