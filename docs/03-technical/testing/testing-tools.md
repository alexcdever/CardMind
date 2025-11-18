# 测试工具与技术

本文档详细介绍了CardMind应用开发过程中使用的测试工具、技术栈、覆盖率要求和最佳实践。

## 目录

- [1. 推荐测试工具](#1-推荐测试工具)
- [2. 测试覆盖率要求](#2-测试覆盖率要求)
- [3. 测试最佳实践](#3-测试最佳实践)
- [4. 测试自动化框架](#4-测试自动化框架)
- [5. 测试环境管理](#5-测试环境管理)

## 1. 推荐测试工具

### 1.1 单元测试工具

| 工具名称 | 版本要求 | 用途 | 配置文件 |
|---------|----------|------|----------|
| Jest | 28.x+ | JavaScript/TypeScript单元测试框架 | jest.config.js |
| React Testing Library | 13.x+ | React组件测试库 | setupTests.ts |
| ts-jest | 28.x+ | TypeScript支持 | jest.config.js |
| Mock Service Worker | 0.42.x+ | API模拟服务 | mocks/msw.ts |

### 1.2 集成测试工具

| 工具名称 | 版本要求 | 用途 | 配置文件 |
|---------|----------|------|----------|
| Playwright | 1.28.x+ | 端到端测试框架 | playwright.config.ts |
| Cypress | 12.x+ | 前端集成测试框架 | cypress.config.ts |
| Supertest | 6.x+ | HTTP API测试工具 | - |
| Axios Mock Adapter | 1.21.x+ | Axios请求模拟 | - |

### 1.3 性能测试工具

| 工具名称 | 版本要求 | 用途 | 配置文件 |
|---------|----------|------|----------|
| Lighthouse | 10.x+ | 性能和可访问性审计 | - |
| Web Vitals | 3.x+ | 核心Web指标监控 | - |
| Chrome DevTools Protocol | - | 浏览器性能分析 | - |

### 1.4 代码质量和静态分析工具

| 工具名称 | 版本要求 | 用途 | 配置文件 |
|---------|----------|------|----------|
| ESLint | 8.x+ | 代码质量检查 | .eslintrc.js |
| Prettier | 2.8.x+ | 代码格式化 | .prettierrc |
| TypeScript | 4.9.x+ | 类型检查 | tsconfig.json |
| SonarQube | 9.x+ | 代码质量和安全分析 | sonar-project.properties |

### 1.5 测试报告和管理工具

| 工具名称 | 版本要求 | 用途 | 配置文件 |
|---------|----------|------|----------|
| Jest HTML Reporter | 3.7.x+ | 单元测试报告生成 | jest.config.js |
| Allure Report | 2.22.x+ | 测试报告可视化 | - |
| Jira Test Management | - | 测试用例和缺陷管理 | - |
| GitHub Actions | - | CI/CD流程中的测试执行 | .github/workflows/test.yml |

## 2. 测试覆盖率要求

### 2.1 总体覆盖率目标

| 覆盖率类型 | 最低要求 | 目标要求 | 衡量工具 |
|-----------|---------|----------|----------|
| 代码覆盖率 | ≥80% | ≥90% | Jest Coverage |
| 分支覆盖率 | ≥75% | ≥85% | Jest Coverage |
| 函数覆盖率 | ≥80% | ≥90% | Jest Coverage |
| 行覆盖率 | ≥80% | ≥90% | Jest Coverage |
| 组件覆盖率 | ≥85% | ≥95% | React Testing Library |

### 2.2 不同模块的覆盖率要求

| 模块 | 代码覆盖率 | 分支覆盖率 | 说明 |
|------|------------|------------|------|
| 核心服务API | ≥90% | ≥85% | 包括AuthService、CardService等核心服务 |
| 状态管理Store | ≥90% | ≥85% | 包括authStore、cardStore等状态管理 |
| 业务逻辑层 | ≥85% | ≥80% | 包含主要业务规则和流程 |
| 工具函数 | ≥95% | ≥90% | 通用工具函数和辅助方法 |
| UI组件 | ≥80% | ≥75% | 不包括纯展示型组件 |
| 配置文件 | ≥50% | - | 关键配置项的测试 |

### 2.3 覆盖率监控和报告

```typescript
// Jest配置示例 - jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  collectCoverage: true,
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/index.tsx',
    '!src/**/*.d.ts',
    '!src/**/mock*.ts',
  ],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 80,
      lines: 80,
      statements: 80,
    },
    './src/services/': {
      branches: 85,
      functions: 90,
      lines: 90,
      statements: 90,
    },
    './src/store/': {
      branches: 85,
      functions: 90,
      lines: 90,
      statements: 90,
    },
  },
  reporters: [
    'default',
    [
      'jest-html-reporters',
      {
        publicPath: './coverage-report',
        filename: 'report.html',
        expand: true,
      },
    ],
  ],
};
```

### 2.4 覆盖率豁免规则

在特殊情况下，某些代码可能无法进行充分测试，可申请覆盖率豁免：

1. **第三方库集成代码**：与外部库紧密耦合的适配代码
2. **浏览器特定API**：无法在测试环境中模拟的浏览器专有功能
3. **错误处理代码**：难以在测试环境中触发的极端错误场景
4. **性能优化代码**：某些性能关键路径上的优化代码

覆盖率豁免需要在代码中添加特定注释并通过代码审查：

```typescript
// coverage-exempt: 浏览器特定API，无法在JSDOM中测试
function browserSpecificFeature() {
  // 浏览器专有功能实现
}
```

## 3. 测试最佳实践

### 3.1 单元测试最佳实践

#### 3.1.1 测试原则

- **单一职责**：每个测试用例只测试一个功能点
- **独立性**：测试用例之间互不依赖
- **可重复性**：相同条件下测试结果应一致
- **可读性**：测试代码应易于理解和维护
- **快速执行**：单元测试应快速运行（毫秒级别）

#### 3.1.2 测试结构

```typescript
// 推荐的测试结构示例
describe('组件/函数名称', () => {
  beforeEach(() => {
    // 设置测试环境
  });

  afterEach(() => {
    // 清理测试环境
  });

  describe('正常情况', () => {
    it('应该执行特定功能', () => {
      // 测试代码
    });
  });

  describe('边界情况', () => {
    it('应该处理空值', () => {
      // 测试边界条件
    });
  });

  describe('错误情况', () => {
    it('应该正确处理异常', () => {
      // 测试错误处理
    });
  });
});
```

#### 3.1.3 Mock策略

- **隔离依赖**：模拟所有外部依赖
- **验证交互**：验证与外部依赖的正确交互
- **使用依赖注入**：便于模拟和替换依赖
- **避免过度模拟**：只模拟必要的依赖，保持测试的真实性

### 3.2 集成测试最佳实践

#### 3.2.1 测试范围

- **关键用户流程**：测试端到端的用户场景
- **组件集成**：测试组件间的正确交互
- **API集成**：测试与后端API的正确交互
- **数据流向**：测试数据在应用中的完整流转

#### 3.2.2 测试策略

- **分层测试**：按功能模块和层次组织测试
- **优先级排序**：先测试核心功能，再测试次要功能
- **并行执行**：尽可能并行执行测试以提高效率
- **环境隔离**：使用独立的测试环境和测试数据

#### 3.2.3 Playwright测试示例

```typescript
// Playwright测试示例
describe('CardMind应用集成测试', () => {
  beforeEach(async ({ page }) => {
    // 导航到应用
    await page.goto('http://localhost:3000');
  });

  it('应该能够创建并保存新卡片', async ({ page }) => {
    // 登录应用
    await page.fill('#username', 'testuser');
    await page.fill('#password', 'password123');
    await page.click('#login-button');
    
    // 创建新卡片
    await page.click('#new-card-button');
    await page.fill('#card-title', '测试卡片');
    await page.fill('#card-content', '这是测试内容');
    await page.click('#save-card-button');
    
    // 验证卡片创建成功
    const card = await page.waitForSelector('.card-item');
    expect(await card.isVisible()).toBeTruthy();
    expect(await card.textContent()).toContain('测试卡片');
  });

  it('应该能够同步卡片数据', async ({ page }) => {
    // 触发同步
    await page.click('#sync-button');
    
    // 验证同步状态
    const syncStatus = await page.waitForSelector('.sync-status');
    expect(await syncStatus.textContent()).toContain('同步成功');
  });
});
```

### 3.3 测试数据管理最佳实践

- **数据隔离**：使用专用的测试数据，避免影响生产数据
- **数据准备**：测试前准备好所需的测试数据
- **数据清理**：测试后清理测试数据，保持环境清洁
- **数据复用**：创建可复用的测试数据集
- **数据生成**：使用工具自动生成测试数据

### 3.4 持续集成中的测试最佳实践

- **自动化测试**：在CI流程中自动执行所有测试
- **测试报告**：生成并保存测试报告
- **覆盖率监控**：持续监控代码覆盖率变化
- **快速反馈**：测试失败时立即通知相关人员
- **并行测试**：在CI环境中并行执行测试以节省时间

## 4. 测试自动化框架

### 4.1 Jest配置和使用

```javascript
// jest.config.js 完整配置
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  rootDir: process.cwd(),
  modulePaths: ['<rootDir>/src'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '\.(css|less|scss|sass)$': 'identity-obj-proxy',
    '\.(jpg|jpeg|png|gif|webp|svg)$': '<rootDir>/src/test/mocks/fileMock.js',
  },
  setupFilesAfterEnv: ['<rootDir>/src/test/setupTests.ts'],
  testPathIgnorePatterns: ['<rootDir>/node_modules/', '<rootDir>/dist/'],
  collectCoverage: true,
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/index.tsx',
    '!src/serviceWorker.ts',
    '!src/setupProxy.js',
    '!src/**/*.d.ts',
    '!src/**/mock*.ts',
  ],
  coverageDirectory: '<rootDir>/coverage',
  coverageReporters: ['lcov', 'text-summary', 'html'],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
  reporters: [
    'default',
    [
      'jest-junit',
      {
        outputDirectory: '<rootDir>/test-results',
        outputName: 'jest-results.xml',
      },
    ],
  ],
  watchPlugins: [
    'jest-watch-typeahead/filename',
    'jest-watch-typeahead/testname',
  ],
};
```

```typescript
// src/test/setupTests.ts
import '@testing-library/jest-dom';
import { server } from './mocks/msw';

// 启动MSW服务
beforeAll(() => server.listen());

// 每个测试后重置所有请求处理器
afterEach(() => server.resetHandlers());

// 测试完成后关闭服务
afterAll(() => server.close());
```

### 4.2 Playwright配置和使用

```typescript
// playwright.config.ts
import { PlaywrightTestConfig, devices } from '@playwright/test';

const config: PlaywrightTestConfig = {
  testDir: './src/e2e',
  timeout: 30 * 1000,
  expect: {
    timeout: 5000,
  },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['junit', { outputFile: 'test-results/playwright-results.xml' }],
  ],
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
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

### 4.3 Mock Service Worker配置

```typescript
// src/test/mocks/msw.ts
import { setupServer } from 'msw/node';
import { rest } from 'msw';
import { mockAuthResponse, mockCards, mockSyncResponse } from './mockData';

const API_BASE_URL = 'https://api.cardmind.example.com';

export const server = setupServer(
  // 模拟认证API
  rest.post(`${API_BASE_URL}/auth/login`, (req, res, ctx) => {
    return res(ctx.json(mockAuthResponse));
  }),
  
  // 模拟卡片API
  rest.get(`${API_BASE_URL}/cards`, (req, res, ctx) => {
    return res(ctx.json(mockCards));
  }),
  
  // 模拟同步API
  rest.post(`${API_BASE_URL}/sync`, (req, res, ctx) => {
    return res(ctx.json(mockSyncResponse));
  })
);
```

## 5. 测试环境管理

### 5.1 环境变量配置

```dotenv
# .env.test - 测试环境变量
NODE_ENV=test
REACT_APP_API_URL=https://api.cardmind.test.example.com
REACT_APP_SYNC_INTERVAL=30000
REACT_APP_DEBUG=true
JEST_JUNIT_OUTPUT_DIR=./test-results
```

### 5.2 Docker测试环境

```dockerfile
# Dockerfile.test
FROM node:18-alpine

WORKDIR /app

# 安装依赖
COPY package*.json ./
RUN npm ci

# 复制代码
COPY . .

# 构建应用
RUN npm run build

# 运行测试
CMD ["npm", "test"]
```

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.test
    environment:
      - NODE_ENV=test
      - REACT_APP_API_URL=http://mock-api:3001
    depends_on:
      - mock-api

  mock-api:
    image: mockoon/cli:latest
    volumes:
      - ./mock-api:/data
    command: -d /data/mock-definition.json -p 3001
    ports:
      - "3001:3001"
```

### 5.3 CI/CD测试配置

```yaml
# .github/workflows/test.yml
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Use Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      - run: npm ci
      - run: npm test -- --ci --coverage
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Use Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run build
      - run: npm run test:e2e
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Use Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run type-check
```

## 相关文档

- [API接口设计与单元测试](../api/api-interfaces-testing.md)
- [状态管理Store API](../api/store-apis-testing.md)
- [系统测试计划](./system-testing-plan.md)
- [回归测试计划](./regression-testing-plan.md)
- [用户界面测试](./ui-testing.md)

[返回技术文档索引](../api-testing-design-index.md)