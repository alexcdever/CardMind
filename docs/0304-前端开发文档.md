# CardMind 前端开发指南

## 1. 概述

本文档介绍CardMind应用的前端开发规范，包括核心组件定义、交互逻辑、状态管理、性能优化和辅助功能实现。

## 2. 核心组件定义

### 2.1 卡片列表组件 (CardList)

**状态类型**
```typescript
interface CardListState {
  cards: Card[];
  loading: boolean;
  error: string | null;
  refreshing: boolean;
  searchQuery: string;
  filterOptions: {
    showDeleted: boolean;
    sortBy: 'createdAt' | 'updatedAt';
    sortOrder: 'asc' | 'desc';
  };
}
```

**核心功能**
- 卡片数据加载与刷新
- 搜索过滤与排序
- 卡片项渲染
- 下拉刷新功能

### 2.2 卡片编辑器组件 (CardEditor)

**状态类型**
```typescript
interface CardEditorState {
  id: string | null;
  title: string;
  content: string;
  saving: boolean;
  error: string | null;
  isNewCard: boolean;
  maxTitleLength: number;
  maxContentLength: number;
}
```

**组件接口**
```typescript
interface CardEditorProps {
  initialCard?: Card;
  onClose: () => void;
  onSaveSuccess: (card: Card) => void;
}
```

**核心功能**
- 卡片标题和内容编辑
- 实时字数统计和验证
- 保存和取消操作
- 错误处理

### 2.3 网络认证组件 (NetworkAuth)

**状态类型**
```typescript
interface NetworkAuthState {
  accessCode: string;
  isGenerating: boolean;
  isJoining: boolean;
  error: string | null;
  showAdvanced: boolean;
  autoJoinMode: boolean;
}
```

**组件接口**
```typescript
interface NetworkAuthProps {
  onSuccess: () => void;
}
```

**核心功能**
- Access Code输入与验证
- 新网络生成
- 网络加入
- 跳过网络设置选项

## 3. 组件交互逻辑

### 3.1 卡片列表交互

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
  
  // 组件渲染...
};
```

### 3.2 卡片编辑器交互

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
  
  // 组件渲染...
};
```

## 4. 页面导航与路由

### 4.1 路由配置

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
```

### 4.2 受保护路由

```typescript
// 受保护的路由组件
const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ isAuthenticated, children }) => {
  if (!isAuthenticated) {
    // 未认证状态下重定向到认证页面
    return <Navigate to="/auth" replace />;
  }
  
  return <>{children}</>;
};
```

## 5. 模态框与对话框管理

### 5.1 模态框上下文

**类型定义**
```typescript
interface ModalContextType {
  openModal: (modalType: ModalType, props?: any) => void;
  closeModal: () => void;
  currentModal: { type: ModalType | null; props: any };
}

// 模态框类型
type ModalType = 'cardDetail' | 'cardEditor' | 'confirmDialog' | 'settings' | 'networkSetup';
```

### 5.2 模态框提供者组件

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
  
  // 组件渲染...
};
```

## 6. 事件总线与跨组件通信

### 6.1 事件类型定义

```typescript
type EventType = 
  | 'card:created'
  | 'card:updated'
  | 'card:deleted'
  | 'card:restored'
  | 'sync:started'
  | 'sync:completed'
  | 'sync:failed'
  | 'network:joined'
  | 'network:left'
  | 'peer:connected'
  | 'peer:disconnected';

// 事件回调类型
type EventCallback<T = any> = (data?: T) => void;
```

### 6.2 事件总线实现

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
}

// 导出事件总线实例
export const eventBus = new EventBus();
```

### 6.3 跨组件通信示例

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
  
  // 组件渲染...
};
```

## 7. React Hooks 接口

### 7.1 响应式Hook

```typescript
function useResponsive(): {
  deviceType: 'mobile' | 'tablet' | 'desktop';
  isMobile: boolean;
  isTablet: boolean;
  isDesktop: boolean;
};
```

### 7.2 模态框Hook

```typescript
function useModal(): {
  openModal: (modalType: ModalType, props?: any) => void;
  closeModal: () => void;
  currentModal: { type: ModalType | null; props: any };
};
```

### 7.3 快捷键Hook

```typescript
function useShortcuts(): {
  registerShortcut: (shortcut: Shortcut) => () => void;
  getAllShortcuts: () => Shortcut[];
};
```

### 7.4 防抖Hook

```typescript
function useDebounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void;
```

### 7.5 懒加载Hook

```typescript
function useLazyComponent<T extends React.ComponentType<any>>(
  importFn: () => Promise<{ default: T }>
): {
  Component: T | null;
  loading: boolean;
  error: Error | null;
  loadComponent: () => Promise<T>;
};
```

## 8. 性能优化策略

### 8.1 组件懒加载

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
```

### 8.2 虚拟列表

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
  
  // 组件渲染...
};
```

### 8.3 防抖与节流

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
```

## 9. 键盘快捷键与辅助功能

### 9.1 快捷键定义

```typescript
interface Shortcut {
  key: string;
  altKey?: boolean;
  ctrlKey?: boolean;
  metaKey?: boolean;
  shiftKey?: boolean;
  description: string;
  action: () => void;
}
```

### 9.2 快捷键管理器

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
}
```

### 9.3 辅助功能Hook

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

## 10. 动画与过渡效果

### 10.1 动画Hook

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
    reducedMotionMode
  };
}
```

### 10.2 淡入淡出过渡组件

```typescript
// 淡入淡出过渡组件
const FadeTransition: React.FC<FadeTransitionProps> = ({
  in: inProp,
  children,
  timeout = 300,
  unmountOnExit = false,
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
    // 进入动画逻辑...
  };
  
  const exit = async () => {
    // 退出动画逻辑...
  };
  
  // 组件渲染...
};
```