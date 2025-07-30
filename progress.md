# 删除按钮问题检查记录

## 2025-07-28 16:54

### 问题描述
- 列表页卡片中的删除按钮点击后显示"删除成功"提示，但实际文档未被删除

### 检查步骤
1. 检查DocumentGallery.tsx中的删除逻辑
   - 发现调用了blockManager的deleteBlock方法
   - 删除后有fetchAllBlocks和setBlocks更新状态
2. 检查blockManager.ts中的deleteBlock实现
   - 发现deleteBlock方法有一个条件判断：只有当要删除的块是当前打开的块时才会执行删除操作
   - 这解释了为什么列表页中的删除按钮不生效

### 解决方案
1. 修改blockManager.ts中的deleteBlock方法，移除了不必要的条件限制
   - 现在可以删除任何块，而不仅限于当前打开的块
2. 修改已保存，可以测试删除功能是否正常工作
