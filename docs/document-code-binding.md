# 文档与代码强绑定机制

## 1. 概述

本文档定义了CardMind项目中实现文档与代码强绑定的机制，旨在确保文档内容与代码实现保持同步，提高文档的准确性和可维护性。

## 2. 绑定策略

### 2.1 双向引用机制

#### 2.1.1 代码引用文档
在代码文件顶部添加文档引用注释：
```typescript
/**
 * @文档 ../../docs/03-technical/api/03-api-01-auth-service-api.md
 * @文档 ../../docs/03-technical/0306-auth-service-implementation.md
 */
```

#### 2.1.2 文档引用代码
在文档中使用特殊标记引用代码：
```markdown
<!-- CODE_REF: src/services/authService.ts:1-50 -->
```

### 2.2 自动化验证

实现一个验证脚本，定期检查：
1. 代码引用的文档是否存在
2. 文档引用的代码行是否有效
3. 文档与代码的版本一致性

### 2.3 统一命名规范

确保文档和代码使用相同的命名规范，便于自动关联：
- 服务类名与文档文件名保持一致
- 方法名与文档中的接口定义保持一致

## 3. 实现方案

### 3.1 创建绑定配置文件

```json
{
  "bindings": [
    {
      "codePath": "src/services/authService.ts",
      "docsPath": [
        "docs/03-technical/api/03-api-01-auth-service-api.md"
      ],
      "version": "1.0.0"
    },
    {
      "codePath": "src/services/cardService.ts",
      "docsPath": [
        "docs/03-technical/api/03-api-03-card-service-api.md"
      ],
      "version": "1.0.0"
    }
  ]
}
```

### 3.2 代码注释规范

在代码中添加标准化注释：

```typescript
/**
 * 生成新的网络ID
 * @文档 ../../docs/03-technical/api/03-api-01-auth-service-api.md#generateNetworkId
 * @returns 生成的网络ID
 */
generateNetworkId(): string {
  // 实现代码
}
```

### 3.3 文档引用规范

在文档中使用标准化引用：

```markdown
### 2.1 生成网络ID

<!-- CODE_REF: src/services/authService.ts:60-80 -->

#### 2.1.1 方法签名
```typescript
// src/services/authService.ts
function generateNetworkId(): string
```

#### 2.1.2 实现细节
该方法使用UUID生成随机码，并结合设备地址和时间戳生成唯一的网络ID。
```