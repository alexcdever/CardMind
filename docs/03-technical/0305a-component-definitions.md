# CardMind 组件定义文档

## 1. 概述

本文档详细描述CardMind应用的所有UI组件定义，包括组件接口、状态类型、属性定义等基础结构。本文档作为UI交互逻辑文档的配套文件，专注于组件的静态定义部分。

## 2. 核心组件定义

### 2.1 卡片列表组件 (CardList)

#### 状态类型定义
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

### 2.2 卡片编辑器组件 (CardEditor)

#### 状态类型定义
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

#### 组件接口
```typescript
interface CardEditorProps {
  initialCard?: Card;
  onClose: () => void;
  onSaveSuccess: (card: Card) => void;
}
```

### 2.3 网络认证组件 (NetworkAuth)

#### 状态类型定义
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

#### 组件接口
```typescript
interface NetworkAuthProps {
  onSuccess: () => void;
}
```

## 3. 页面导航与路由组件

### 3.1 受保护路由组件

#### 组件接口
```typescript
interface ProtectedRouteProps {
  isAuthenticated: boolean;
  children: React.ReactNode;
}
```

## 4. 模态框与对话框组件

### 4.1 模态框上下文

#### 类型定义
```typescript
interface ModalContextType {
  openModal: (modalType: ModalType, props?: any) => void;
  closeModal: () => void;
  currentModal: { type: ModalType | null; props: any };
}

// 模态框类型
type ModalType = 'cardDetail' | 'cardEditor' | 'confirmDialog' | 'settings' | 'networkSetup';
```

#### 组件接口
```typescript
interface ModalProviderProps {
  children: React.ReactNode;
}
```

### 4.2 确认对话框选项

```typescript
interface ConfirmDialogOptions {
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  confirmVariant?: 'primary' | 'danger' | 'default';
  onConfirm: () => void;
  onCancel?: () => void;
}
```

### 4.3 消息提示选项

```typescript
interface ToastOptions {
  message: string;
  type?: 'success' | 'error' | 'warning' | 'info';
  duration?: number;
  position?: 'top' | 'bottom' | 'top-right' | 'bottom-right';
  onClose?: () => void;
}
```

## 5. 事件总线定义

### 5.1 事件类型

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

## 6. 响应式设计组件

### 6.1 响应式布局组件

#### 组件接口
```typescript
interface ResponsiveLayoutProps {
  children: React.ReactNode;
}
```

### 6.2 响应式卡片网格

#### 组件接口
```typescript
interface ResponsiveCardGridProps {
  cards: Card[];
  onCardClick: (card: Card) => void;
}
```

## 7. 键盘快捷键定义

### 7.1 快捷键类型

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

## 8. 性能优化组件

### 8.1 虚拟列表组件

#### 组件接口
```typescript
interface VirtualListProps<T> {
  items: T[];
  itemHeight: number;
  containerHeight: number;
  renderItem: (item: T, index: number) => React.ReactNode;
  keyExtractor: (item: T) => string;
  overscanCount?: number;
  onScroll?: (scrollTop: number) => void;
}
```

## 9. 动画与过渡组件

### 9.1 动画配置类型

```typescript
interface AnimationConfig {
  duration?: number;
  easing?: string;
  delay?: number;
  iterations?: number | 'infinite';
  direction?: 'normal' | 'reverse' | 'alternate' | 'alternate-reverse';
  fillMode?: 'none' | 'forwards' | 'backwards' | 'both';
}
```

### 9.2 淡入淡出过渡组件

#### 组件接口
```typescript
interface FadeTransitionProps {
  in: boolean;
  children: React.ReactNode;
  timeout?: number;
  unmountOnExit?: boolean;
  onEnter?: (node: HTMLElement) => void;
  onEntering?: (node: HTMLElement) => void;
  onEntered?: (node: HTMLElement) => void;
  onExit?: (node: HTMLElement) => void;
  onExiting?: (node: HTMLElement) => void;
  onExited?: (node: HTMLElement) => void;
  className?: string;
}
```

### 9.3 滑入过渡组件

#### 组件接口
```typescript
interface SlideTransitionProps extends FadeTransitionProps {
  direction?: 'left' | 'right' | 'up' | 'down';
  distance?: string;
}
```

## 10. 工具类接口定义

### 10.1 响应式工具类

```typescript
class ResponsiveUtils {
  // 获取当前设备类型
  static getDeviceType(): 'mobile' | 'tablet' | 'desktop';
  
  // 检查是否为移动设备
  static isMobile(): boolean;
  
  // 检查是否为平板设备
  static isTablet(): boolean;
  
  // 检查是否为桌面设备
  static isDesktop(): boolean;
  
  // 监听窗口大小变化
  static onResize(callback: (deviceType: 'mobile' | 'tablet' | 'desktop') => void): () => void;
  
  // 获取响应式类名
  static getResponsiveClassName(baseClassName: string, variations: {
    mobile?: string;
    tablet?: string;
    desktop?: string;
  }): string;
}
```

### 10.2 辅助功能工具类

```typescript
class AccessibilityUtils {
  // 设置焦点到元素
  static focusElement(element: HTMLElement | null): void;
  
  // 创建跳过导航链接
  static createSkipLink(targetId: string, text?: string): HTMLAnchorElement;
  
  // 使元素可访问
  static makeAccessible(element: HTMLElement, options: {
    role?: string;
    ariaLabel?: string;
    ariaLabelledby?: string;
    ariaDescribedby?: string;
    ariaLive?: 'assertive' | 'polite' | 'off';
    ariaHidden?: boolean;
  }): void;
  
  // 创建实时区域
  static createLiveRegion(id: string, ariaLive?: 'assertive' | 'polite'): HTMLElement;
  
  // 通知屏幕阅读器
  static announce(message: string, id?: string): void;
  
  // 检查高对比度模式
  static isHighContrastMode(): boolean;
  
  // 检查减少动画模式
  static isReducedMotionMode(): boolean;
}
```

### 10.3 动画工具类

```typescript
class AnimationUtils {
  // 执行CSS动画
  static animateElement(
    element: HTMLElement,
    keyframes: Keyframe[] | PropertyIndexedKeyframes,
    config?: AnimationConfig
  ): Promise<void>;
  
  // 淡入动画
  static fadeIn(element: HTMLElement, config?: AnimationConfig): Promise<void>;
  
  // 淡出动画
  static fadeOut(element: HTMLElement, config?: AnimationConfig): Promise<void>;
  
  // 滑入动画
  static slideIn(element: HTMLElement, direction?: 'left' | 'right' | 'top' | 'bottom', config?: AnimationConfig): Promise<void>;
  
  // 弹跳动画
  static bounce(element: HTMLElement, config?: AnimationConfig): Promise<void>;
  
  // 脉冲动画
  static pulse(element: HTMLElement, config?: AnimationConfig): Promise<void>;
  
  // 停止元素上的所有动画
  static stopAnimation(element: HTMLElement): void;
  
  // 获取动画状态
  static getAnimationState(element: HTMLElement): Animation[];
}
```

### 10.4 导航服务

```typescript
class NavigationService {
  // 导航到主页
  navigateToHome(): void;
  
  // 导航到认证页面
  navigateToAuth(): void;
  
  // 导航到设置页面
  navigateToSettings(): void;
  
  // 导航到引导页
  navigateToOnboarding(): void;
  
  // 重新加载当前页面
  reload(): void;
  
  // 返回上一页
  goBack(): void;
  
  // 清除导航历史并跳转
  redirectTo(url: string): void;
  
  // 打开外部链接
  openExternalLink(url: string, target?: '_blank' | '_self' | '_parent' | '_top'): void;
}
```

### 10.5 快捷键管理器

```typescript
class ShortcutManager {
  // 注册快捷键
  register(shortcut: Shortcut): void;
  
  // 注销快捷键
  unregister(shortcut: Shortcut): void;
  
  // 开始监听键盘事件
  startListening(): void;
  
  // 停止监听键盘事件
  stopListening(): void;
  
  // 获取所有注册的快捷键
  getAllShortcuts(): Shortcut[];
  
  // 清除所有快捷键
  clear(): void;
}
```

### 10.6 事件总线

```typescript
class EventBus {
  // 订阅事件
  on<T = any>(event: EventType, callback: EventCallback<T>): () => void;
  
  // 取消订阅
  off<T = any>(event: EventType, callback: EventCallback<T>): void;
  
  // 触发事件
  emit<T = any>(event: EventType, data?: T): void;
  
  // 订阅一次事件
  once<T = any>(event: EventType, callback: EventCallback<T>): () => void;
  
  // 清除所有事件监听器
  clear(): void;
  
  // 获取事件监听器数量
  getListenersCount(event?: EventType): number;
}
```

## 11. React Hooks 接口

### 11.1 响应式Hook

```typescript
function useResponsive(): {
  deviceType: 'mobile' | 'tablet' | 'desktop';
  isMobile: boolean;
  isTablet: boolean;
  isDesktop: boolean;
};
```

### 11.2 模态框Hook

```typescript
function useModal(): {
  openModal: (modalType: ModalType, props?: any) => void;
  closeModal: () => void;
  currentModal: { type: ModalType | null; props: any };
};
```

### 11.3 快捷键Hook

```typescript
function useShortcuts(): {
  registerShortcut: (shortcut: Shortcut) => () => void;
  getAllShortcuts: () => Shortcut[];
};
```

### 11.4 辅助功能Hook

```typescript
function useAccessibility(): {
  highContrastMode: boolean;
  reducedMotionMode: boolean;
  announce: (message: string, id?: string) => void;
  focusElement: (element: HTMLElement | null) => void;
  makeAccessible: (element: HTMLElement, options: any) => void;
};
```

### 11.5 动画Hook

```typescript
function useAnimation(): {
  animateElement: (element: HTMLElement, keyframes: any, config?: AnimationConfig) => Promise<void>;
  fadeIn: (element: HTMLElement, config?: AnimationConfig) => Promise<void>;
  fadeOut: (element: HTMLElement, config?: AnimationConfig) => Promise<void>;
  slideIn: (element: HTMLElement, direction?: string, config?: AnimationConfig) => Promise<void>;
  bounce: (element: HTMLElement, config?: AnimationConfig) => Promise<void>;
  pulse: (element: HTMLElement, config?: AnimationConfig) => Promise<void>;
  stopAnimation: (element: HTMLElement) => void;
  getAnimationState: (element: HTMLElement) => Animation[];
  reducedMotionMode: boolean;
};
```

### 11.6 防抖Hook

```typescript
function useDebounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void;
```

### 11.7 懒加载Hook

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