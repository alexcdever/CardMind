#!/usr/bin/env python3
"""批量更新规格文件的引用格式"""

import re
import os
from pathlib import Path

def update_spec_file(filepath):
    """更新单个规格文件"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # 移除旧的规格编号部分
    # 匹配: ## 📋 规格编号: SP-XXX-YYY 及其后续的版本、状态、依赖信息
    pattern = r'## 📋 规格编号:.*?\n(?:\*\*[^*]+\*\*:.*?\n)*---'

    # 查找是否有这个模式
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print(f"  跳过 {filepath.name} (无旧格式)")
        return False

    # 提取版本、状态信息
    version_match = re.search(r'\*\*版本\*\*:\s*([^\n]+)', match.group(0))
    status_match = re.search(r'\*\*状态\*\*:\s*([^\n]+)', match.group(0))
    deps_match = re.search(r'\*\*依赖\*\*:\s*(.*?)(?=\n\*\*|\n---)', match.group(0), re.DOTALL)

    version = version_match.group(1).strip() if version_match else "1.0.0"
    status = status_match.group(1).strip() if status_match else "Active"

    # 解析依赖项并转换为Markdown链接
    deps_text = ""
    if deps_match:
        deps_raw = deps_match.group(1).strip()
        # 简化：根据常见的依赖模式生成链接
        # SP-CARD-004 → card_store.md
        # SP-SPM-001 → pool_model.md
        # SP-SYNC-006 → sync_protocol.md
        dep_map = {
            'SP-CARD-004': '[card_store.md](../../domain/card_store.md)',
            'SP-SPM-001': '[pool_model.md](../../domain/pool_model.md)',
            'SP-POOL-003': '[pool_model.md](../../domain/pool_model.md)',
            'SP-SYNC-006': '[sync_protocol.md](../../domain/sync_protocol.md)',
            'SP-ADAPT': '[adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)',
            'SP-FLT-SHR-002': '[home_screen/shared.md](../home_screen/shared.md)',
        }

        # 如果有依赖，生成简化的依赖列表
        if any(key in deps_raw for key in dep_map.keys()):
            deps_links = []
            for key, link in dep_map.items():
                if key in deps_raw:
                    deps_links.append(link)
            if deps_links:
                deps_text = f"\n**依赖**: {', '.join(deps_links)}"

    # 获取文件标题
    title_match = re.search(r'^# (.+)', content, re.MULTILINE)
    title = title_match.group(1) if title_match else "规格"

    # 构建新的头部
    new_header = f"""# {title}

**版本**: {version}
**状态**: {status}{deps_text}

---"""

    # 替换旧格式
    content = re.sub(pattern, new_header, content, flags=re.DOTALL)

    # 写回文件
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✅ 更新 {filepath.name}")
        return True
    else:
        print(f"  跳过 {filepath.name} (无变化)")
        return False

def main():
    """主函数"""
    specs_dir = Path('openspec/specs')

    # 查找所有需要更新的文件
    patterns = [
        'features/*/*.md',
        'domain/*.md',
        'api/*.md',
    ]

    updated_count = 0
    for pattern in patterns:
        files = list(specs_dir.glob(pattern))
        for filepath in files:
            if filepath.name in ['README.md', 'DEPRECATED.md']:
                continue
            if update_spec_file(filepath):
                updated_count += 1

    print(f"\n总计更新 {updated_count} 个文件")

if __name__ == '__main__':
    main()
