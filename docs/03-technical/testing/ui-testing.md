# 用户界面测试

本文档详细描述了CardMind应用的用户界面测试计划，包括测试目标、测试场景和Playwright测试脚本示例。用户界面测试旨在验证应用的UI元素、交互逻辑和用户体验是否符合设计要求。

## 目录

- [1. 测试目标](#1-测试目标)
- [2. 测试环境](#2-测试环境)
- [3. 测试场景](#3-测试场景)
- [4. Playwright测试脚本示例](#4-playwright测试脚本示例)
- [5. 测试覆盖率策略](#5-测试覆盖率策略)
- [6. UI测试最佳实践](#6-ui测试最佳实践)

## 1. 测试目标

### 1.1 功能正确性

- 验证所有UI元素是否按预期工作
- 确认用户交互操作能够正确触发相应功能
- 测试表单提交、数据展示等核心交互功能
- 验证错误提示和异常情况的正确处理

### 1.2 用户体验

- 验证UI响应速度满足性能要求
- 测试不同屏幕尺寸下的响应式布局
- 验证键盘导航和辅助功能的可用性
- 测试加载状态和反馈机制

### 1.3 兼容性

- 验证在不同浏览器中的一致表现
- 测试在不同操作系统上的兼容性
- 验证在移动设备上的良好体验
- 测试不同分辨率和缩放比例下的显示效果

### 1.4 一致性

- 验证UI设计元素的一致性（颜色、字体、间距等）
- 确认交互模式的一致性
- 测试状态保持和页面切换的一致性
- 验证错误提示和用户反馈的一致性

## 2. 测试环境

### 2.1 浏览器环境

| 浏览器 | 版本 | 操作系统 |
|--------|------|----------|
| Chrome | 最新2个主要版本 | Windows, macOS, Linux |
| Firefox | 最新2个主要版本 | Windows, macOS, Linux |
| Safari | 最新2个主要版本 | macOS, iOS |
| Edge | 最新2个主要版本 | Windows |

### 2.2 设备环境

| 设备类型 | 代表设备 | 分辨率 |
|----------|----------|--------|
| 桌面端 | 标准显示器 | 1920x1080 |
| 平板端 | iPad (最新) | 1024x768 |
| 移动端 | iPhone (最新), Android手机 | 375x667 |

### 2.3 网络环境

- 良好网络（>10Mbps）
- 一般网络（2-10Mbps）
- 较差网络（<2Mbps）
- 不稳定网络（模拟网络波动）

### 2.4 环境设置

```typescript
// playwright.config.ts - UI测试专用配置示例
import { PlaywrightTestConfig, devices } from '@playwright/test';

const config: PlaywrightTestConfig = {
  testDir: './src/e2e/ui',
  timeout: 40 * 1000,
  expect: {
    timeout: 5000,
  },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['junit', { outputFile: 'test-results/ui-results.xml' }],
  ],
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    headless: process.env.CI ? true : false,
  },
  projects: [
    // 桌面端测试
    {
      name: 'Desktop Chrome',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'Desktop Firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'Desktop Safari',
      use: { ...devices['Desktop Safari'] },
    },
    // 移动端测试
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    },
  ],
  webServer: {
    command: 'npm run start:test',
    url: 'http://localhost:3000',
    timeout: 120 * 1000,
    reuseExistingServer: !process.env.CI,
  },
};

export default config;
```

## 3. 测试场景

### 3.1 登录页面测试

#### 3.1.1 测试目标

验证登录页面的UI元素、表单验证和登录功能是否正常工作。

#### 3.1.2 测试场景

| 场景ID | 场景描述 | 测试步骤 | 预期结果 |
|--------|----------|----------|----------|
| UI-LOGIN-001 | 登录页面布局验证 | 1. 访问登录页面<br>2. 检查页面标题<br>3. 检查输入框、按钮等元素 | 所有元素正确显示，布局符合设计 |
| UI-LOGIN-002 | 有效登录验证 | 1. 输入有效用户名和密码<br>2. 点击登录按钮 | 登录成功，跳转到主页面 |
| UI-LOGIN-003 | 无效登录验证 | 1. 输入无效用户名或密码<br>2. 点击登录按钮 | 显示错误提示，不允许登录 |
| UI-LOGIN-004 | 表单验证反馈 | 1. 不输入任何信息点击登录<br>2. 输入格式错误的邮箱<br>3. 输入过短的密码 | 显示相应的验证错误提示 |
| UI-LOGIN-005 | 记住我功能 | 1. 勾选"记住我"<br>2. 登录成功<br>3. 关闭并重新打开浏览器<br>4. 访问应用 | 用户已保持登录状态 |

### 3.2 卡片管理页面测试

#### 3.2.1 测试目标

验证卡片列表页面和卡片编辑页面的UI元素和功能是否正常工作。

#### 3.2.2 测试场景

| 场景ID | 场景描述 | 测试步骤 | 预期结果 |
|--------|----------|----------|----------|
| UI-CARD-001 | 卡片列表显示 | 1. 登录应用<br>2. 访问卡片列表页面 | 所有卡片正确显示，支持滚动浏览 |
| UI-CARD-002 | 创建新卡片 | 1. 点击"新建卡片"按钮<br>2. 输入标题和内容<br>3. 点击保存 | 卡片创建成功，显示在列表顶部 |
| UI-CARD-003 | 编辑卡片 | 1. 点击卡片的"编辑"按钮<br>2. 修改内容<br>3. 点击保存 | 卡片内容更新成功 |
| UI-CARD-004 | 删除卡片 | 1. 点击卡片的"删除"按钮<br>2. 在确认对话框点击"确认" | 卡片从列表中移除 |
| UI-CARD-005 | 搜索卡片 | 1. 在搜索框输入关键词<br>2. 观察搜索结果 | 只显示匹配的卡片 |
| UI-CARD-006 | 过滤卡片 | 1. 使用过滤下拉菜单选择分类<br>2. 观察过滤结果 | 只显示匹配分类的卡片 |

### 3.3 同步功能UI测试

#### 3.3.1 测试目标

验证同步功能的UI界面和用户反馈是否正常工作。

#### 3.3.2 测试场景

| 场景ID | 场景描述 | 测试步骤 | 预期结果 |
|--------|----------|----------|----------|
| UI-SYNC-001 | 手动同步触发 | 1. 点击"同步"按钮<br>2. 观察同步状态指示 | 显示同步进行中状态，完成后显示成功 |
| UI-SYNC-002 | 同步状态指示 | 1. 触发同步<br>2. 观察同步状态指示器 | 同步过程中显示进度或加载动画 |
| UI-SYNC-003 | 同步冲突提示 | 模拟同步冲突场景 | 显示冲突提示，并提供解决方案选项 |
| UI-SYNC-004 | 同步错误处理 | 模拟网络错误<br>2. 触发同步 | 显示错误提示，并提供重试选项 |

### 3.4 响应式设计测试

#### 3.4.1 测试目标

验证应用在不同屏幕尺寸下的响应式布局是否正常工作。

#### 3.4.2 测试场景

| 场景ID | 场景描述 | 测试步骤 | 预期结果 |
|--------|----------|----------|----------|
| UI-RESP-001 | 桌面端布局验证 | 使用桌面分辨率访问应用 | 布局显示多列，侧边栏可见 |
| UI-RESP-002 | 平板端布局验证 | 使用平板分辨率访问应用 | 布局适当调整，保持可用性 |
| UI-RESP-003 | 移动端布局验证 | 使用移动设备分辨率访问应用 | 切换为单列布局，底部导航可见 |
| UI-RESP-004 | 旋转设备响应 | 在移动设备上旋转屏幕 | 布局自动适应新的屏幕方向 |

## 4. Playwright测试脚本示例

### 4.1 登录页面测试脚本

```typescript
// login.spec.ts
import { test, expect } from '@playwright/test';

test.describe('登录页面测试', () => {
  test.beforeEach(async ({ page }) => {
    // 导航到登录页面
    await page.goto('/login');
  });

  test('登录页面布局验证', async ({ page }) => {
    // 检查页面标题
    await expect(page).toHaveTitle(/CardMind - 登录/);
    
    // 检查关键元素是否存在
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('h1')).toHaveText('欢迎登录 CardMind');
    
    await expect(page.locator('#username')).toBeVisible();
    await expect(page.locator('#password')).toBeVisible();
    await expect(page.locator('#login-button')).toBeVisible();
    await expect(page.locator('#remember-me')).toBeVisible();
    
    // 检查布局结构
    const form = page.locator('form');
    await expect(form).toBeVisible();
    expect(await form.locator('input').count()).toBeGreaterThanOrEqual(2);
    expect(await form.locator('button').count()).toBeGreaterThanOrEqual(1);
  });

  test('有效登录验证', async ({ page }) => {
    // 输入有效凭证
    await page.fill('#username', 'testuser');
    await page.fill('#password', 'password123');
    
    // 点击登录按钮
    await page.click('#login-button');
    
    // 验证是否成功登录并跳转到主页面
    await page.waitForURL('/dashboard');
    await expect(page).toHaveURL(/dashboard/);
    await expect(page.locator('.user-welcome')).toBeVisible();
  });

  test('无效登录验证', async ({ page }) => {
    // 输入无效凭证
    await page.fill('#username', 'invaliduser');
    await page.fill('#password', 'wrongpassword');
    
    // 点击登录按钮
    await page.click('#login-button');
    
    // 验证是否显示错误消息
    const errorMessage = page.locator('.error-message');
    await expect(errorMessage).toBeVisible();
    await expect(errorMessage).toHaveText(/用户名或密码错误/);
    
    // 验证没有跳转到主页面
    await expect(page).not.toHaveURL(/dashboard/);
  });

  test('表单验证反馈', async ({ page }) => {
    // 不输入任何信息直接点击登录
    await page.click('#login-button');
    
    // 验证必填字段错误提示
    await expect(page.locator('#username-error')).toBeVisible();
    await expect(page.locator('#password-error')).toBeVisible();
    
    // 输入格式错误的邮箱
    await page.fill('#username', 'invalid-email');
    await page.click('#login-button');
    await expect(page.locator('#username-error')).toHaveText(/请输入有效的邮箱地址/);
    
    // 输入过短的密码
    await page.fill('#username', 'test@example.com');
    await page.fill('#password', '123');
    await page.click('#login-button');
    await expect(page.locator('#password-error')).toHaveText(/密码长度至少为6位/);
  });
});
```

### 4.2 卡片管理测试脚本

```typescript
// cards.spec.ts
import { test, expect } from '@playwright/test';

test.describe('卡片管理测试', () => {
  test.beforeEach(async ({ page }) => {
    // 导航到登录页面并登录
    await page.goto('/login');
    await page.fill('#username', 'testuser');
    await page.fill('#password', 'password123');
    await page.click('#login-button');
    
    // 导航到卡片列表页面
    await page.waitForURL('/dashboard');
    await page.click('#cards-nav');
  });

  test('卡片列表显示', async ({ page }) => {
    // 验证卡片列表标题
    await expect(page.locator('h1')).toHaveText('我的卡片');
    
    // 验证至少显示一个卡片（假设测试数据中已有卡片）
    const cardItems = page.locator('.card-item');
    await expect(cardItems.first()).toBeVisible();
    
    // 验证每个卡片包含必要元素
    const firstCard = cardItems.first();
    await expect(firstCard.locator('.card-title')).toBeVisible();
    await expect(firstCard.locator('.card-actions')).toBeVisible();
  });

  test('创建新卡片', async ({ page }) => {
    // 点击新建卡片按钮
    await page.click('#new-card-button');
    
    // 输入卡片信息
    const cardTitle = `测试卡片 ${Date.now()}`;
    await page.fill('#card-title', cardTitle);
    await page.fill('#card-content', '这是一个测试卡片的内容');
    
    // 保存卡片
    await page.click('#save-card-button');
    
    // 验证卡片创建成功并显示在列表顶部
    const newCard = page.locator('.card-item').first();
    await expect(newCard).toBeVisible();
    await expect(newCard.locator('.card-title')).toContainText(cardTitle);
  });

  test('编辑卡片', async ({ page }) => {
    // 获取第一个卡片的标题
    const firstCard = page.locator('.card-item').first();
    const originalTitle = await firstCard.locator('.card-title').textContent();
    
    // 点击编辑按钮
    await firstCard.locator('.edit-button').click();
    
    // 修改标题
    const newTitle = `${originalTitle} (已编辑)`;
    await page.fill('#card-title', newTitle);
    
    // 保存修改
    await page.click('#save-card-button');
    
    // 验证卡片已更新
    await expect(firstCard.locator('.card-title')).toHaveText(newTitle);
  });

  test('搜索卡片', async ({ page }) => {
    // 创建一个测试卡片用于搜索
    await page.click('#new-card-button');
    const searchableTitle = `搜索测试卡片 ${Date.now()}`;
    await page.fill('#card-title', searchableTitle);
    await page.fill('#card-content', '这是用于测试搜索功能的内容');
    await page.click('#save-card-button');
    
    // 在搜索框中输入关键词
    await page.fill('#card-search', searchableTitle.split(' ')[0]);
    
    // 验证只显示匹配的卡片
    const cardItems = page.locator('.card-item');
    await expect(cardItems).toHaveCount(1);
    await expect(cardItems.first().locator('.card-title')).toContainText(searchableTitle);
    
    // 清除搜索
    await page.fill('#card-search', '');
    await expect(cardItems).toHaveCount(await cardItems.count());
  });
});
```

### 4.3 响应式设计测试脚本

```typescript
// responsive.spec.ts
import { test, expect } from '@playwright/test';

test.describe('响应式设计测试', () => {
  test.beforeEach(async ({ page }) => {
    // 导航到登录页面并登录
    await page.goto('/login');
    await page.fill('#username', 'testuser');
    await page.fill('#password', 'password123');
    await page.click('#login-button');
    await page.waitForURL('/dashboard');
  });

  test('桌面端布局验证', async ({ page }) => {
    // 设置桌面视口
    await page.setViewportSize({ width: 1920, height: 1080 });
    
    // 验证侧边栏可见
    await expect(page.locator('#sidebar')).toBeVisible();
    
    // 验证卡片网格布局（假设有网格容器）
    const gridContainer = page.locator('.card-grid');
    await expect(gridContainer).toBeVisible();
    
    // 验证多列布局（通过检查CSS属性）
    const gridTemplateColumns = await gridContainer.evaluate(
      el => window.getComputedStyle(el).gridTemplateColumns
    );
    expect(gridTemplateColumns).toContain('repeat'); // 确保使用了repeat()函数
    
    // 验证移动端导航不可见
    await expect(page.locator('#mobile-nav')).not.toBeVisible();
  });

  test('平板端布局验证', async ({ page }) => {
    // 设置平板视口
    await page.setViewportSize({ width: 768, height: 1024 });
    
    // 可能的情况：侧边栏可能折叠或有不同的显示方式
    const sidebar = page.locator('#sidebar');
    await expect(sidebar).toBeVisible();
    
    // 验证卡片网格布局可能调整为更少的列
    const gridContainer = page.locator('.card-grid');
    
    // 可能需要调整移动端导航的显示状态
    await expect(page.locator('#mobile-nav')).not.toBeVisible();
  });

  test('移动端布局验证', async ({ page }) => {
    // 设置移动端视口
    await page.setViewportSize({ width: 375, height: 667 });
    
    // 侧边栏可能隐藏或通过菜单按钮触发
    const sidebar = page.locator('#sidebar');
    
    // 验证移动端导航可见
    await expect(page.locator('#mobile-nav')).toBeVisible();
    
    // 验证卡片可能是单列布局
    const gridContainer = page.locator('.card-grid');
    if (await gridContainer.isVisible()) {
      const gridTemplateColumns = await gridContainer.evaluate(
        el => window.getComputedStyle(el).gridTemplateColumns
      );
      // 在移动端可能是单列布局
      expect(gridTemplateColumns).toContain('1fr');
    }
  });

  test('旋转设备响应', async ({ page }) => {
    // 设置竖屏视口
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/cards');
    
    // 获取竖屏状态下的布局信息
    const verticalLayout = await page.locator('.card-grid').evaluate(
      el => window.getComputedStyle(el).gridTemplateColumns
    );
    
    // 旋转为横屏
    await page.setViewportSize({ width: 667, height: 375 });
    
    // 获取横屏状态下的布局信息
    const horizontalLayout = await page.locator('.card-grid').evaluate(
      el => window.getComputedStyle(el).gridTemplateColumns
    );
    
    // 验证布局发生了变化
    expect(verticalLayout).not.toEqual(horizontalLayout);
  });
});
```

## 5. 测试覆盖率策略

### 5.1 UI组件覆盖率

- **核心组件**：100% UI测试覆盖
- **常用组件**：90% UI测试覆盖
- **辅助组件**：75% UI测试覆盖
- **装饰性组件**：50% UI测试覆盖

### 5.2 用户流程覆盖率

- **主要用户流程**：100% 端到端测试覆盖
- **次要用户流程**：90% 端到端测试覆盖
- **边缘用户流程**：75% 端到端测试覆盖

### 5.3 测试执行频率

- **日常开发**：每个PR必须通过基本UI测试
- **夜间构建**：执行完整UI测试套件
- **发布前**：在所有目标设备和浏览器上执行完整测试

## 6. UI测试最佳实践

### 6.1 测试编写原则

- **使用用户行为而非实现细节**：模拟真实用户操作，避免依赖内部实现
- **保持测试独立性**：每个测试应该独立运行，不依赖其他测试的状态
- **使用合适的选择器**：优先使用data-testid、id等稳定选择器
- **设置合理的等待时间**：使用Playwright的等待机制而非固定延迟
- **清理测试数据**：测试结束后清理创建的数据，保持环境清洁

### 6.2 常见问题处理

- **不稳定测试**：使用重试机制、添加适当的等待条件、检查元素状态
- **速度优化**：使用并行执行、优先测试关键路径、模拟慢速响应
- **环境差异**：在多种环境中测试，使用Docker确保环境一致性
- **大型测试套件管理**：分类测试、优先级排序、按需执行

### 6.3 调试技巧

- 使用Playwright的trace和screenshot功能记录失败测试
- 使用headless: false模式观察测试执行
- 使用Playwright Inspector调试复杂交互
- 利用视频录制功能回放测试过程

## 相关文档

- [API接口设计与单元测试](../api/api-interfaces-testing.md)
- [状态管理Store API](../api/store-apis-testing.md)
- [系统测试计划](./system-testing-plan.md)
- [回归测试计划](./regression-testing-plan.md)
- [测试工具与技术](./testing-tools.md)

[返回技术文档索引](../api-testing-design-index.md)