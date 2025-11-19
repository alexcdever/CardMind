# CardMind 项目文档指南

## 1. 文档阅读指南

1. **项目概述** → 了解项目目标：`docs/01-requirements/requirements.md`
2. **环境搭建** → 本地运行项目：`docs/03-technical/tech-stack.md`
3. **开发指南** → 贡献代码前必读：
   - 编码规范：`docs/03-technical/tech-concepts.md`
   - 功能实现计划：`docs/03-technical/implementation-plan.md`
4. **测试要求** → 提PR前验证：`docs/04-testing/lan-interconnection-test.md`

## 2. 常见问题解答 (FAQ)

- **Q：本地启动报错？**
  - A：请检查Node版本是否≥16，具体要求可参考`docs/03-technical/tech-stack.md`的"开发环境"小节

- **Q：API接口如何调用？**
  - A：详细说明请参考`docs/03-technical/api-testing-design.md`，文档中包含Postman测试示例

- **Q：如何实现多设备数据同步？**
  - A：请阅读`docs/03-technical/offline-lan-architecture.md`了解离线局域网同步架构

- **Q：分布式环境下数据冲突如何解决？**
  - A：方案详情请查看`docs/01-requirements/requirements.md`中的"数据合并"部分，我们使用yjs的CRDT算法实现

## 3. 代码贡献指南

1. Fork本仓库
2. 基于develop分支创建feature分支
3. 遵循编码规范开发，参考相关功能的实现计划
4. 运行测试确保代码质量
5. 提交PR并关联对应Issue

## 4. 项目文档结构

```
docs/
├── 01-requirements/     # 需求类文档
│   └── requirements.md              # 项目需求文档
├── 02-design/           # 设计类文档
│   └── ui-design.md                 # UI设计文档
├── 03-technical/        # 技术类文档
│   ├── tech-stack.md                  # 技术栈文档
│   ├── tech-concepts.md               # 技术概念文档
│   ├── implementation-plan.md        # 实现计划
│   ├── api-testing-design.md          # API测试设计
│   ├── component-definitions.md       # 组件定义
│   ├── interaction-logic.md           # 交互逻辑
│   ├── cross-platform-architecture.md # 跨平台架构
│   ├── offline-lan-architecture.md    # 离线局域网架构
│   ├── local-signaling-server.md      # 本地信令服务器
│   ├── cross-platform-compatibility.md # 跨平台兼容性
│   ├── pure-p2p-architecture.md       # 纯P2P架构
│   └── security-authentication.md     # 安全认证设计
└── 04-testing/         # 测试类文档
    └── lan-interconnection-test.md     # 局域网互联测试
```

## 5. 文档阅读建议

- **基础必读**：需求文档、环境搭建指南、贡献规范
- **开发参考**：组件定义、交互逻辑、API文档
- **深入研究**：架构设计、跨平台实现、安全认证机制

## 6. 文档维护规范

- 修改代码涉及文档变更时，提交信息必须包含"文档更新"关键词
- 关键技术文档（架构、API等）在相关代码中添加文档链接注释
- 迭代开发完成后，检查并更新文档与代码的一致性
- 过期文档请在文件名前添加`deprecated-`前缀或直接归档