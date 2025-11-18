# CardMind 项目文档导航

## 1. 阅读顺序（按这个来，少走弯路）

1. **先看「需求文档」** → 知道项目做啥：`docs/01-requirements/requirements.md`
2. **再看「环境搭建」** → 本地跑通项目：`docs/03-technical/tech-stack.md`
3. **想贡献代码** → 看「编码规范」+「功能实现计划」：
   - `docs/03-technical/tech-concepts.md`
   - `docs/03-technical/implementation-plan.md`
4. **提PR前** → 看「测试指南」→ 确保代码合格：`docs/04-testing/lan-interconnection-test.md`

## 2. 核心疑问（FAQ）

- **Q：本地启动报错？**
  - A：检查Node版本≥16，参考`tech-stack.md`的"开发环境"小节

- **Q：接口怎么调用？**
  - A：看`api-testing-design.md`，附Postman测试示例

- **Q：如何实现多设备同步？**
  - A：参考`offline-lan-architecture.md`了解离线局域网架构

- **Q：数据冲突如何解决？**
  - A：查看`requirements.md`中的"数据合并"部分，了解yjs的CRDT算法实现

## 3. 贡献方式

1. Fork仓库 → 基于develop分支创建feature分支
2. 按编码规范开发，参考对应功能的实现计划
3. 跑通测试用例，提PR时关联对应Issue

## 4. 文档结构概览

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

## 5. 文档层级说明

- **入门层（必看）**：需求概览、环境搭建、快速上手示例
- **进阶层（按需看）**：详细设计、接口文档、编码规范
- **深入层（可选看）**：技术选型理由、实现细节、历史迭代记录

## 6. 维护指南

- 提交代码时，如果涉及文档变更，提交信息必须包含"文档更新"
- 关键文档（如架构、接口）在代码中留"文档链接"
- 每完成1个小迭代，检查是否有冗余内容和文档代码不一致的情况
- 过期文档直接删除或在文件名前加`deprecated-`